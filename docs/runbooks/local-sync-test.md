# Runbook: local LiveSync test against the dev stack

Sets up a throwaway CouchDB database and a non-admin user for it, then walks
through syncing a copy of the fixture vault from Obsidian with Self-hosted
LiveSync. Use it to prove `config/20-livesync.ini` works before changing it or
upgrading the plugin. Never point it at a real vault.

Phase 2's `vault add` will replace the setup section. Until then, these are the
steps.

## Before you start

- The stack is up (`podman compose up -d`, see the README's "Run locally").
- `scripts/check-couchdb-config` passes.
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

# 2. The user. No roles, so it's not a server admin. The body comes from a
#    process substitution so the secret stays out of argv.
as_admin -X PUT "$COUCH/_users/org.couchdb.user:livesync-test" \
  -H 'Content-Type: application/json' \
  --data-binary @<(printf '{"name":"livesync-test","password":"%s","roles":[],"type":"user"}' "$TEST_PASS")

# 3. Make the user a member of this database only.
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
3. In LiveSync's setup, choose manual setup with CouchDB:
   - URI `http://127.0.0.1:5984`
   - username `livesync-test`, and the test user's secret from setup
   - database `livesync-test`
4. Turn **End-to-end encryption** on, with a `<throwaway passphrase>`.
5. Run **Check server requirements** (sometimes "Check database
   configuration"). It's read-only until you click a fix button.
   - [ ] It reports nothing to change.
   - If it offers to change a setting, **decline**, and note the key. A change
     it offers means `config/20-livesync.ini` is wrong, so fix the ini there.
     Accepting would write the setting into `local.d/docker.ini`, outside the
     repo, and `scripts/check-couchdb-config` would then report drift.
6. Start sync (LiveSync mode is fine).
   - [ ] The initial sync completes without errors.
7. Note the database's current sequence, then edit a note in Obsidian and let
   it sync:

   ```bash
   as_admin "$COUCH/livesync-test/_changes?descending=true&limit=5"
   ```

   - [ ] A new change appears after the edit (a higher `last_seq`, with a new
     entry at the top). With E2EE, document ids may be obfuscated, so look
     for the new entry rather than the note's file name.
8. Record which `_security` shape worked:
   - [ ] `members` was enough, or
   - [ ] the database `admins` fallback was needed (and what failed without it).
9. Re-run `scripts/check-couchdb-config`.
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
