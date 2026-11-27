# Runbook: local LiveSync test against the dev stack

Sets up a throwaway CouchDB database and a non-admin user for it, then walks
through syncing a copy of the fixture vault from Obsidian with Self-hosted
LiveSync. Use it to prove `config/20-livesync.ini` works before changing it or
upgrading the plugin. Never point it at a real vault.

Phase 2's `vault add` will replace the setup section. Until then, these are the
steps.

## Before you start

- The stack is up and its config checks clean: run `./liquid-sync init`
  (see the README's "Run locally"). It ends with `init: done`.
- Run the shell steps below in **bash**. zsh's `read -p` does something else.
- Pick a throwaway secret for the test user. You'll type it into Obsidian, so
  avoid `"` and `\` (the helpers below don't escape them).

## Setup

Enter the credentials once per shell. `read -rs` keeps them out of your
history and off the screen.

```bash
COUCH=http://127.0.0.1:5984
read -rp 'CouchDB admin user: ' ADMIN_USER
read -rsp 'CouchDB admin password (COUCHDB_PASSWORD in couchdb.env): ' ADMIN_PASS; echo
read -rsp 'New password for livesync-test: ' TEST_PASS; echo

# Credentials go to curl on stdin (--config -), never in argv.
as_admin()  { printf 'user = "%s:%s"\n' "$ADMIN_USER" "$ADMIN_PASS" | curl -sS --config - -w '\nHTTP %{http_code}\n' "$@"; }
as_tester() { printf 'user = "livesync-test:%s"\n' "$TEST_PASS" | curl -sS --config - -w '\nHTTP %{http_code}\n' "$@"; }
```

Then create the database, the user, and the database's member list. Each step
is idempotent. A second run gives `412` (database exists) and `409` (user
exists), and `_security` is simply rewritten (`200`).

```bash
# 1. The database, created by the server admin.
as_admin -X PUT "$COUCH/livesync-test"

# 2. The user. No roles, so it's not a server admin. The body travels in the
#    same curl config on stdin as the admin login, so no secret is in argv.
#    (Not a <(...) process substitution: macOS's bash 3.2 closes its file
#    before curl can read it.)
printf 'user = "%s:%s"\ndata-binary = "{\\"name\\":\\"livesync-test\\",\\"password\\":\\"%s\\",\\"roles\\":[],\\"type\\":\\"user\\"}"\n' "$ADMIN_USER" "$ADMIN_PASS" "$TEST_PASS" \
  | curl -sS --config - -w '\nHTTP %{http_code}\n' -X PUT -H 'Content-Type: application/json' \
    "$COUCH/_users/org.couchdb.user:livesync-test"

# 3. Make the user a member of this database only. A 404 here means the
#    database doesn't exist: run step 1 first.
as_admin -X PUT "$COUCH/livesync-test/_security" \
  -H 'Content-Type: application/json' \
  -d '{"admins":{"names":[],"roles":[]},"members":{"names":["livesync-test"],"roles":[]}}'
```

### Check the user is confined to its database

```bash
as_admin -X PUT "$COUCH/other-test"                # a second database to probe; 201, or 412 if it exists
as_tester "$COUCH/livesync-test"                   # 200
as_tester "$COUCH/_all_dbs"                        # 401 "You are not a server admin."
as_tester "$COUCH/other-test"                      # 403 "You are not allowed to access this db."
as_tester -X PUT "$COUCH/other-test/probe" -d '{}' # 403
as_tester "$COUCH/_node/_local/_config"            # 401 "You are not a server admin."
```

`other-test` is created with no `_security` members, which in CouchDB 3 means
only admins can read it. CouchDB answers the server-wide endpoints with `401`
even though the user is signed in: that's its "not a server admin" response.
The `200` on `livesync-test` shows the credentials themselves work.

### If LiveSync needs more than membership

In 0003's test (LiveSync at the pinned commit), `members` was enough for
syncing, and this fallback wasn't needed. It's kept in case a later plugin
version writes design documents.

Database members can't write design documents. If LiveSync fails on a
`_design/` write, make the user an admin of **this database only** (still not
a server admin), and note it in the PR:

```bash
as_admin -X PUT "$COUCH/livesync-test/_security" \
  -H 'Content-Type: application/json' \
  -d '{"admins":{"names":["livesync-test"],"roles":[]},"members":{"names":["livesync-test"],"roles":[]}}'
```

## Manual checklist (Obsidian on the Mac)

For E2EE, use a `<throwaway passphrase>`. Never reuse a real one, and never
paste it anywhere.

1. Make a copy of the fixture vault: `scripts/fixture-vault --to <dir>` (a path
   outside the repo that doesn't exist yet).
2. Open `<dir>` as a vault in Obsidian, and install and enable
   **Self-hosted LiveSync**.
3. Open onboarding from the **Welcome to Self-hosted LiveSync** notice. These
   labels follow LiveSync's [quick setup, "Configure CouchDB manually on the
   first device"](https://github.com/vrtmrz/obsidian-livesync/blob/70899e2fd44277e564173d2c45ee7fde6f499185/docs/quick_setup.md#configure-couchdb-manually-on-the-first-device)
   at the pinned commit.
   - Choose **I am setting this up for the first time**, and confirm.
   - On **Connection Method**, choose **Configure a remote manually**, then
     **Proceed with manual configuration**. Don't choose "Use a Setup URI".
     That wants an `obsidian://setuplivesync?settings=…` link, and there isn't
     one here.
4. On **End-to-End Encryption**, turn it on with a `<throwaway passphrase>`.
   **Obfuscate Properties** is optional; on is closer to real use.
5. On **Choose a synchronisation remote**, choose **CouchDB**, then
   **Continue to CouchDB setup**, and enter:
   - URL `http://127.0.0.1:5984`
   - the **server admin** login for now (`$COUCHDB_USER` and
     `$COUCHDB_PASSWORD` from `couchdb.env`). Steps 6 and 7 need it, and
     step 9 switches to `livesync-test`.
   - database `livesync-test`

   LiveSync's [own server guide](https://github.com/vrtmrz/obsidian-livesync/blob/70899e2fd44277e564173d2c45ee7fde6f499185/docs/setup_own_server.md)
   splits the same way: provisioning uses the admin, and LiveSync stores a
   routine login with access to the one database.
6. Run **Check server requirements**. It reads the whole server config
   (`/_node/_local/_config`), which only a server admin can read. As
   `livesync-test` it stops with "Access forbidden." It's read-only until you
   confirm a change.
   - [ ] It reports nothing to change.
   - If it offers to change a setting, **decline**, and note the key. With the
     admin login a fix button really would write the setting. A change it
     offers means `config/20-livesync.ini` is wrong, so fix the ini there.
     Accepting would write the setting into `local.d/docker.ini`, outside the
     repo, and `scripts/check-couchdb-config` would then report drift.
7. Choose **Create or connect to database and continue**, then **Restart and
   Initialise Server**, then **I Understand, Overwrite Server**. That's safe
   here: the database is new and the vault is a fixture copy. If **No
   Synchronisation Settings Found** appears, choose **Use this device's
   settings**.
   - [ ] The initial sync completes without errors.

   "Overwrite Server" deletes the database and creates it again
   (`tryResetRemoteDatabase` in LiveSync's CouchDB library), and deleting a
   database needs a server admin. A members-only user, or even an admin of
   just that database, can't do it. The new database comes back with the
   default admin-only `_security`, so the test user has lost its access.
8. Give `livesync-test` its access back by re-running setup step 3 (the
   `_security` members PUT). It's idempotent.
9. In LiveSync's settings, change the remote login to `livesync-test` and its
   secret. Keep the URL and the database.
   - If it offers to rebuild, fetch or overwrite, **decline**. The database is
     already initialised, and an overwrite would need the admin again.
   - Sync can stay paused after a settings change. Run **Replicate now** from
     the command palette, and check that **Sync Mode** is `LiveSync` (or
     periodic).
10. Edit a note or two and let them sync. Then check, as the admin:

    ```bash
    as_admin "$COUCH/livesync-test/_changes?descending=true&limit=5"
    # CouchDB logs to stderr, hence 2>&1. Set --since to cover only the time
    # since step 9, so step 6's expected 401 isn't counted.
    podman logs --since 10m liquid-sync-couchdb 2>&1 | grep ' livesync-test ' | grep -cE '(POST /livesync-test/_bulk_docs|PUT /livesync-test/[^ ]*) 201 '
    podman logs --since 10m liquid-sync-couchdb 2>&1 | grep ' livesync-test ' | grep -E ' (401|403) '
    ```

    - [ ] New changes appear at the top of `_changes` (a higher sequence).
      With E2EE and Obfuscate Properties the ids are hashes (`f:…`, `h:…`),
      so look for new entries rather than the note's file name.
    - [ ] The log shows writes as `livesync-test` (a count above 0), and the
      last command prints nothing (no 401 or 403).
11. Record what each step needed:
    - [ ] Syncing: `members` was enough, or the database `admins` fallback was
      needed (and what failed without it).
    - [ ] Initialising: needed the server admin.
12. Re-run `scripts/check-couchdb-config`.
    - [ ] It still passes, so nothing wrote to the server config.

Record the ticked list in the PR. Leave out every credential, and the
`<throwaway passphrase>` too.

## Teardown

```bash
as_admin -X DELETE "$COUCH/livesync-test"
as_admin -X DELETE "$COUCH/other-test"
rev=$(as_admin "$COUCH/_users/org.couchdb.user:livesync-test" | sed -n 's/.*"_rev":"\([^"]*\)".*/\1/p')
as_admin -X DELETE "$COUCH/_users/org.couchdb.user:livesync-test?rev=$rev"
unset ADMIN_PASS TEST_PASS
```

Then close the vault in Obsidian and delete its copy. Or drop everything at
once with `podman compose down -v`, which also deletes the data volume.
