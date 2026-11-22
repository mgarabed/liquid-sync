---
id: 0003
title: Configure CouchDB for LiveSync in config/local.ini
stage: spec
from: intent.md
---
# Spec: Configure CouchDB for LiveSync in config/local.ini

## Areas of concern
- [x] **"Any origin" can't be combined with credentials.** CouchDB's docs say: "You can't set origins = * and credentials = true option at the same time" ([CouchDB: CORS](https://docs.couchdb.org/en/stable/config/http.html)). LiveSync sends credentials, and its own provisioning sets `cors/credentials = true` with `cors/origins = app://obsidian.md,capacitor://localhost,http://localhost` ([provision.ts](https://github.com/vrtmrz/obsidian-livesync/blob/main/utils/couchdb/provision.ts)). So the intent's "any origin for now" is either broken or undefined behaviour. — Proposed resolution: use LiveSync's own three-origin list now. That is exactly what 0009 was going to tighten to, so 0009 is rejected as done-by-0003. The alternative is `origins = *` with `credentials = false`, which LiveSync would then have to work without. It's untested and may fail auth from the mobile webview. — decided: LiveSync's three origins with credentials. 0009 is redundant.
- [x] **Which settings, and from where.** LiveSync's setup doc doesn't list them. Its provisioning script writes them through CouchDB's config API ([couchdb-init.sh](https://github.com/vrtmrz/obsidian-livesync/blob/main/utils/couchdb/couchdb-init.sh), [provision.ts](https://github.com/vrtmrz/obsidian-livesync/blob/main/utils/couchdb/provision.ts)). — decided: the spec takes the values from `provision.ts` at the commit read during build, and records that commit hash in the ini's header comment. It sets nothing beyond them.
- [x] **The config API writes to the last ini file, which drifts from the repo.** An API write (by LiveSync's provisioning or by its in-app fix button) lands in `local.d/docker.ini`, the last file in the chain, so it isn't declared in the repo (no pets). — decided: every setting lives in `config/20-livesync.ini`. The check script reads the live values through the API and fails if they differ from the file, which catches drift from any source. The checklist says to run LiveSync's "Check server requirements" read-only and to decline any server change it offers. A change offered there means the ini is wrong, so fix the ini.
- [x] **A non-admin user may not be able to write design documents.** CouchDB database members can read and write documents but not design documents; only database admins can ([CouchDB: security](https://docs.couchdb.org/en/stable/api/database/security.html)). LiveSync's docs only say the account needs "the required access to this database" ([setup_own_server.md](https://github.com/vrtmrz/obsidian-livesync/blob/main/docs/setup_own_server.md)). Its provisioning creates the database with the sync user's credentials (accepting 412 if it already exists) and writes a version document. — decided: create the database as the server admin, and add the test user to the database's `_security.members` by name. If LiveSync then fails on a design-document write, move the user to that database's `_security.admins` (still not a server admin), and record which one was needed. Phase 2's `vault add` inherits the answer.
- [x] **Reading live config needs the server admin.** `_node/_local/_config` is admin-only. — decided: the check script reads `COUCHDB_USER` and `COUCHDB_PASSWORD` from `couchdb.env` (or the environment, if set). It passes the credentials to curl through a `--config` file on stdin, never in argv or in output. It prints keys and values only for settings, never for credentials.
- [x] **The compose file and quadlets don't change.** 0002's entrypoint wrapper already copies every `config/*.ini` into `local.d/`. — decided: no `compose.yaml` edit, so `scripts/check-quadlets` passes unchanged. That's checked, not assumed.
- [x] Dependencies and history: 0002 (merged) provides the stack, the `config/` copy-in and `couchdb.env`. 0004 (building, not yet merged) provides the fixture vault and `scripts/fixture-vault`. 0003 already depends on 0004, so `sdlc start` waits for it. 0009 (draft) depends on this item and is affected by the CORS decision. No other prior work touches these files.

## Requirements
- R1: `config/20-livesync.ini` sets every CouchDB setting LiveSync's provisioning applies (`require_valid_user` in both `chttpd` and `chttpd_auth`, `WWW-Authenticate`, `enable_cors` in both `httpd` and `chttpd`, `max_http_request_size`, `max_document_size`, and the `cors` credentials and origins). Each value matches the cited upstream source.
- R2: After `podman compose up -d`, every key in `config/20-livesync.ini` reads back from the running CouchDB with the same value, and a check script proves it, failing on any mismatch.
- R3: CouchDB refuses every unauthenticated request, including `/`, `/_up` and the test database.
- R4: A CORS preflight from `app://obsidian.md` gets an allow response with credentials. A preflight from an origin that isn't listed gets no allow-origin header.
- R5: A documented, repeatable procedure creates the test database and a non-admin test user who can sync that database and no other. The user can't read another database or the server config.
- R6: The owner's manual checklist passes on the Mac, using a copy of the 0004 fixture vault, with E2EE on and a throwaway passphrase:
  - LiveSync's server check reports no required changes
  - the vault syncs up
  - a later edit in Obsidian reaches CouchDB

  The result is recorded in the PR without credentials or the passphrase.
- R7: No secret (admin password, test user password, passphrase) appears in git, in the check script's output, or in the PR.
- R8: The existing checks still pass: `scripts/check-quadlets` and `sdlc verify`.

## Design
- **`config/20-livesync.ini` (new).**
  - A header comment cites the `provision.ts` commit.
  - It sets `[chttpd]`, `[chttpd_auth]`, `[httpd]`, `[couchdb]` and `[cors]` with the R1 keys.
  - It sorts after `10-single-node.ini` and before `docker.ini`.
- **`scripts/check-couchdb-config` (new, bash, `set -euo pipefail`, `--help`).**
  - Parses `section`, `key` and `value` from every `config/*.ini` (skipping comments and blank lines).
  - GETs each one from `http://127.0.0.1:5984/_node/_local/_config/<section>/<key>` as the admin and compares the JSON string. It prints `ok` or `MISMATCH section/key` (with expected and actual for settings only) and exits 1 on any mismatch or connection failure.
  - Read-only and idempotent. This is the seed of `doctor`'s "CouchDB config drift" check (project plan component 8).
- **Test user procedure, in `docs/runbooks/local-sync-test.md` (new).**
  - Uses shell variables entered with `read -rs`, so passwords stay out of history.
  - `PUT /livesync-test` as the admin.
  - `PUT /_users/org.couchdb.user:livesync-test` with `type: user` and `roles: []`.
  - `PUT /livesync-test/_security` with `{"admins":{"names":[],"roles":[]},"members":{"names":["livesync-test"],"roles":[]}}`.
  - Each step is idempotent (412 or 409 means already done).
  - Then the manual checklist (R6):
    - `scripts/fixture-vault --to <dir>`
    - open that directory in Obsidian and install LiveSync
    - enter `http://127.0.0.1:5984`, the test user and the `livesync-test` database
    - turn E2EE on with a throwaway passphrase
    - run "Check server requirements" (read-only, declining any change)
    - sync, edit a note, and confirm the change reached CouchDB with an admin curl on `_changes`
  - The runbook's teardown drops the database and the user.
- **README "Run locally" (edit):** one line pointing at the runbook, and the `/_up` example keeps `-u`.
- **Not changed:** `compose.yaml`, `deploy/quadlets/`, `couchdb.env.example`, `.sdlc/config.toml`.
- **Rollback:** revert the merge. Locally, `podman compose down -v` drops the test database and user along with the volume.

## Acceptance criteria
- AC1 (R1): `config/20-livesync.ini` contains each of the nine keys. A read against `provision.ts` at the cited commit finds every value matching, and that comparison is pasted in the PR.
- AC2 (R2): after `podman compose up -d`, `scripts/check-couchdb-config` exits 0 and prints `ok` for every key. Running it after setting one key to a different value via `PUT _node/_local/_config/couchdb/max_document_size` exits 1 and names `couchdb/max_document_size`. The temporary change is then reverted by PUTting the ini's value back (a restart keeps it, because a config API write lands in `local.d/docker.ini`), and the check passes again.
- AC3 (R3): `curl -s -o /dev/null -w '%{http_code}'` without credentials on `/`, `/_up`, `/_all_dbs` and `/livesync-test` → `401` each.
- AC4 (R4): `curl -si -X OPTIONS -H 'Origin: app://obsidian.md' -H 'Access-Control-Request-Method: GET' http://127.0.0.1:5984/livesync-test` shows `Access-Control-Allow-Origin: app://obsidian.md` and `Access-Control-Allow-Credentials: true`. The same request with `Origin: https://example.com` shows no `Access-Control-Allow-Origin` header.
- AC5 (R5): after the runbook's setup steps, run twice to show they're idempotent:
  - as the test user, `GET /livesync-test` → 200
  - `GET /_all_dbs` → 401 or 403 (denied; CouchDB 3.5 answers 401 "You are not a server admin."). CouchDB 3's `[chttpd] admin_only_all_dbs` default should give this. If it's 200, the build stops and reports rather than adding a setting LiveSync's list doesn't include.
  - `PUT /other-test` (created by the admin) → 403
  - `GET /_node/_local/_config` → 401 or 403 (denied; CouchDB 3.5 answers 401 "You are not a server admin.")
- AC6 (R6): the PR body has the owner's ticked checklist:
  - the server check passed with no changes accepted
  - the initial sync completed
  - an edited note's id appears in `_changes`
  - whether `members` was enough or database `admins` was needed
- AC7 (R7): `git diff main | grep -iE 'password|passphrase' | grep -vE 'read -rs|COUCHDB_PASSWORD=$|<|\$\{?[A-Z_]+'` is empty. `scripts/check-couchdb-config` output contains no line from `couchdb.env`.
- AC8 (R8): `scripts/check-quadlets` exits 0. `shellcheck -x scripts/check-couchdb-config` exits 0. `sdlc verify` → `verify: PASS`.

## Open questions
- [x] Does `*` plus credentials work, or does it break the mobile webview? — CouchDB disallows the combination outright. decided: LiveSync's three origins (see the first area of concern).
- [x] Can the settings come from the config file alone, or does LiveSync write extra ones at runtime? — the file alone. LiveSync's provisioning uses the config API, but the same keys can be set in ini. Runtime writes are caught by the check script, and the checklist declines in-app server changes.
- [x] Should the check script live in `scripts/` as part of `doctor`, or be a one-off? — `scripts/check-couchdb-config`, a reusable piece that `doctor` will call or absorb in Phase 2.
- [x] Should the test database and user curl commands become a script now? — no. They're documented steps in `docs/runbooks/local-sync-test.md` until Phase 2's `vault add`, which keeps this item from building half of `vault add`.

## Standards applied
- sdlc:security-baseline:
  - #1: credentials stay out of argv, output and git
  - #2: `require_valid_user`, so there's no anonymous access
  - #4: test data only
  - #7: a non-admin user with access to one database
  - #8: the check fails closed on mismatch or connection error
- ADR 0001: the compose rules are untouched, and the stack stays loopback-only.
- CLAUDE.md:
  - no pets (settings declared in the repo, drift detected)
  - bash with `set -euo pipefail`, shellcheck and `--help`
  - test against a fixture vault only
  - never expose CouchDB publicly
- No stack skill applies (stack `generic`).
