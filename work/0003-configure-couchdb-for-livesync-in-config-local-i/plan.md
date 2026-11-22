---
id: 0003
title: Configure CouchDB for LiveSync in config/local.ini
stage: plan
from: spec.md
---
# Plan: Configure CouchDB for LiveSync in config/local.ini

## Files that change
- `config/20-livesync.ini` (new): the nine LiveSync settings, with a header comment citing the `provision.ts` commit.
- `scripts/check-couchdb-config` (new): bash. It compares every `config/*.ini` key with the live value from `_node/_local/_config`.
- `docs/runbooks/local-sync-test.md` (new): test database and user setup, the owner's checklist, and teardown.
- `README.md` (edit): one line in "Run locally" pointing at the runbook and at `scripts/check-couchdb-config`.

## Order of work
- [x] 1. **Preflight, read-only.** Check that:
  - `PODMAN` resolves (falling back to `/opt/podman/bin/podman`)
  - the machine is rootless and running
  - `docker context show` prints `colima`
  - port 5984 is free
  - `scripts/fixture-vault` exists on main (0004 merged)

  If any check fails, stop and report.
- [x] 2. **Pin the upstream source.** Fetch `utils/couchdb/provision.ts` from `vrtmrz/obsidian-livesync` at the current `main` commit, and record its hash. List the keys and values it PUTs. If the list differs from spec R1 (keys added or removed), stop and report rather than guess.
- [x] 3. **Write `config/20-livesync.ini`** from that list. Values are written as CouchDB ini values, so the JSON string `"true"` becomes `true`. `cors/origins` is `app://obsidian.md,capacitor://localhost,http://localhost`. The header cites the commit URL.
- [ ] 4. **Write `scripts/check-couchdb-config`:**
  - bash, `set -euo pipefail`, `--help`
  - reads `COUCHDB_USER` and `COUCHDB_PASSWORD` from the environment, or else parses only those two keys out of `couchdb.env`, without sourcing it
  - passes them to curl with `--config -` on stdin (`user = "…"`), so they're never in argv
  - parses `config/*.ini`: `[section]` headers, then `key = value`, skipping `;`/`#` comments and blank lines
  - compares each value with `curl -fsS …/_node/_local/_config/<section>/<key>`, JSON-decoded with `sed` (no new tool)
  - prints `ok section/key` or `MISMATCH section/key: expected … got …`
  - exits 1 on any mismatch or curl failure

  Run `shellcheck -x`.
- [ ] 5. **Bring the stack up and prove the server side:**
  - `cp couchdb.env.example couchdb.env`, with a throwaway admin password; if the secrets hook blocks it, ask the owner to run `!cp couchdb.env.example couchdb.env` and set the password
  - `$PODMAN compose up -d`
  - run AC2 (including the mismatch mutation, reverted by re-`PUT`ting the ini's value)
  - run AC3 and AC4
- [ ] 6. **Write `docs/runbooks/local-sync-test.md`:**
  - setup with `read -rs` prompts:
    - create the database
    - create the `_users` doc
    - set `_security` members
  - the R6 checklist
  - teardown: delete the database and the user doc

  Then run the setup steps twice (idempotent), and run AC5 as the test user, creating `other-test` as the admin first.
- [ ] 7. **Owner's manual test: pause here.** Hand the owner the runbook's checklist, and wait for their ticked result and the members-or-admins answer.
  - If LiveSync fails with members only, follow the runbook's fallback (database `_security.admins`), update the runbook to that, and note it in this plan.
  - If LiveSync's server check offers a change, the owner declines it and reports the key. Then fix `config/20-livesync.ini` and repeat from step 5.
- [ ] 8. **README line, clean up and verify:**
  - add the README line
  - `scripts/check-quadlets` exits 0 (compose untouched)
  - run AC7's grep
  - `$PODMAN compose down -v`, then `rm couchdb.env`
  - `sdlc verify` → `verify: PASS`

## Risks
- **The riskiest step is 7, the manual sync.** It depends on LiveSync accepting a pre-created database and a members-only user, which no upstream doc covers. The fallback (database-level admins) is spelled out, and the result feeds Phase 2's `vault add`.
- **`require_valid_user` in `[chttpd_auth]` and `[chttpd]` blocks unauthenticated `/_up`.** The README already uses `-u`. Nothing else in the repo probes CouchDB without credentials (`scripts/check-quadlets` doesn't talk to CouchDB).
- **`max_http_request_size = 4294967296` (4 GB)** is LiveSync's value, and it lets an authenticated client send very large requests. That's acceptable behind loopback now and Tailscale later. A smaller cap can be an ADR-backed change if memory pressure shows up within the 512 MB limit.
- **`WWW-Authenticate = Basic realm="couchdb"`** makes browsers show a login prompt on a 401. That's harmless here, and it's what LiveSync sets.
- **Upstream drift:** if `provision.ts` changes after the pinned commit, the ini stays correct for that commit. A plugin upgrade re-checks it (project plan §5.3: "test on a fixture vault before upgrading clients").
- **The secrets hook may block writing `couchdb.env`.** The owner creates it instead. Nothing in this plan works around the hook.
- **Considered and rejected:**
  - applying the settings through the config API at start (runtime state, not declared in the repo)
  - `origins = *` (CouchDB disallows it with credentials)
  - scripting user creation now (Phase 2's `vault add`)
  - a `jq` dependency for the check script (`sed` suffices for flat JSON strings)
- **Overlaps:** `sdlc dep 0003 --check` found none. 0009 depends on 0003 and is made redundant by the CORS decision. The owner may reject it.

## Proof
- AC1: `grep -cE '^[a-z_A-Z-]+ *=' config/20-livesync.ini` → `9`, and a side-by-side of `provision.ts`'s keys and values at the cited commit is pasted in the PR.
- AC2: `scripts/check-couchdb-config` → exit 0, all `ok`. After `curl … -X PUT …/_node/_local/_config/couchdb/max_document_size -d '"1"'`, it exits 1 naming `couchdb/max_document_size`. A restart won't undo this, because the runtime write lands in `docker.ini`. Revert it by restoring the original value (re-`PUT` the ini's value; a `DELETE` would remove the ini's setting from the running node too), then re-run → exit 0.
- AC3: `for p in / /_up /_all_dbs /livesync-test; do curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:5984$p; done` → four `401`s.
- AC4: `curl -si -X OPTIONS -H 'Origin: app://obsidian.md' -H 'Access-Control-Request-Method: GET' http://127.0.0.1:5984/livesync-test | grep -i '^access-control-allow-'` shows the origin and `credentials: true`. With `Origin: https://example.com`, there's no `access-control-allow-origin` line.
- AC5: as the test user:
  - `GET /livesync-test` → 200
  - `GET /_all_dbs` → 403
  - `GET /other-test` → 403
  - `GET /_node/_local/_config` → 403

  The setup run twice gives 412 or 409 on the second pass, never 5xx.
- AC6: the owner's ticked checklist is in the PR body, with no secrets.
- AC7: `git diff main | grep -iE 'password|passphrase' | grep -vE 'read -rs|COUCHDB_PASSWORD=$|<|\$\{?[A-Z_]+'` → empty. `scripts/check-couchdb-config | grep -F -f couchdb.env` → empty (run before `rm couchdb.env`).
- AC8: `scripts/check-quadlets` → 0, `shellcheck -x scripts/check-couchdb-config` → 0, and `sdlc verify` → `verify: PASS`.
- **Rollback:** revert the merge. Locally, `$PODMAN compose down -v`.

## Parallel tracks
<!-- None: the server proof, the runbook and the manual test run in order. -->
