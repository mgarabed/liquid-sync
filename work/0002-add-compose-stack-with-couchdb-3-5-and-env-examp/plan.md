---
id: 0002
title: Add compose stack with CouchDB 3.5 and .env.example
stage: plan
from: spec.md
---
# Plan: Add compose stack with CouchDB 3.5 and .env.example

## Files that change
- `compose.yaml` (new): the single CouchDB service, written to ADR 0001's compose rules (spec Design).
- `couchdb.env.example` (new): placeholders for `COUCHDB_USER` and `COUCHDB_PASSWORD`.
- `config/10-single-node.ini` (new): `[couchdb]` `single_node = true`, so the system databases exist.
- `deploy/quadlets/couchdb.container`, `deploy/quadlets/liquid-sync.network` (new): podlet output, generated, never hand-edited. If podlet names the files differently, the real names replace these here in the same commit.
- `scripts/check-quadlets` (new): bash; regenerate, diff and dry-run, with a `--write` mode.
- `.gitignore` (edit): `*.env` and `!*.env.example` in the Secrets block.
- `README.md` (edit): a "Run locally" section, and the layout block's `deploy/pi/` line becomes `deploy/quadlets/`.
- `CLAUDE.md` (edit): the Secrets line names per-service `*.env` files with `*.env.example`.
- `docs/project-plan.md` (edit): the Phase 1 `.env.example` bullet; `deploy/pi/` becomes `deploy/` in component 9, §5.3 and Phase 5. Nothing else changes.

## Order of work
- [x] 1. **Preflight, read-only:**
  - `PODMAN=/opt/podman/bin/podman`, unless `podman` is on PATH
  - `$PODMAN machine inspect` shows `rootful=false` and the machine running
  - `docker context show` prints `colima`
  - `ls /var/run/docker.sock` doesn't exist, or doesn't point at Podman
  - `lsof -nP -iTCP:5984 -sTCP:LISTEN` is empty

  If any of these fail, stop and report. Don't change the machine or Colima.
- [ ] 2. **Write the stack files:**
  - `compose.yaml`, `couchdb.env.example` and `config/10-single-node.ini`, as spec Design says
  - the `.gitignore` lines
  - check that `git check-ignore -q couchdb.env` exits 0 and `git check-ignore -q couchdb.env.example` exits 1
  - `$PODMAN compose config -q` exits 0
- [ ] 3. **Run it on rootless Podman:**
  - `cp couchdb.env.example couchdb.env`, with a throwaway password; the file is git-ignored and deleted at the end
  - `$PODMAN compose up -d`, then run AC2, AC3 and AC4
  - If the container fails to start (for example a volume permission error under rootless), read `$PODMAN logs liquid-sync-couchdb` and fix the compose file. Don't switch the machine to rootful.
  - Finish with `$PODMAN compose down -v`
- [x] 4. **Generate and commit the quadlets:**
  - First try podlet with `restart: unless-stopped` in the compose file. If podlet rejects it, drop it from `compose.yaml` and note it here.
  - Generate into `deploy/quadlets/` with the ADR's digest-pinned podlet command (without `--pod`).
  - Read the output:
    - `ContainerName=liquid-sync-couchdb`
    - `AutoUpdate=registry`
    - `Memory=512m`
    - `PublishPort=127.0.0.1:5984:5984`
    - `EnvironmentFile=` is relative
    - the bind mount is relative and has `:Z`
    - `Network=liquid-sync.network`
  - Record in Risks whether podlet needed `couchdb.env` to exist.
- [x] 5. **Write `scripts/check-quadlets`:**
  - bash, `set -euo pipefail`, `--help`, `--write`
  - honours `${PODMAN:-podman}`, and if the binary is missing it fails with a message naming `/opt/podman/bin/podman`
  - stages a temp dir (`mktemp -d`, removed by a trap) holding `compose.yaml`, `config/` and `couchdb.env.example` copied as `couchdb.env`
  - runs the podlet and quadlet images by full digest, copied from ADR 0001's Evidence
  - `diff -r` against `deploy/quadlets/`
  - `quadlet -dryrun -user` on the committed files. It runs even after a diff failure, and the script fails if either step did, so a corrupted quadlet is shown to fail the dry-run itself (AC7).
  - Then run AC7: the clean pass, the `mem_limit` mutation in a scratch copy, and the corrupted-key mutation, plus `shellcheck -x`.
- [ ] 6. **Docker compatibility on Colima** (AC6): with the Podman stack down, `docker compose up -d`, AC3's authenticated call, then `docker compose down -v`. Then run AC9.
- [x] 7. **Docs:**
  - the README's "Run locally" section, using `podman` commands only, plus a line on `scripts/check-quadlets --write` after editing `compose.yaml`
  - the README layout line
  - the CLAUDE.md Secrets line
  - the `docs/project-plan.md` edits
  - Then run AC8.
- [ ] 8. **Clean up and verify:**
  - `rm couchdb.env`
  - `$PODMAN volume ls` shows no `liquid-sync_*` volume left
  - `sdlc verify` → `verify: PASS`. The shellcheck step now covers `scripts/check-quadlets` too.

## Risks
- **The riskiest step is 3: rootless runtime, which is exercised here for the first time.** The entrypoint chowns `/opt/couchdb` as root inside the user namespace, which should work. But `:Z` on a single-file bind mount under the Podman machine's virtiofs share is untested. If relabelling fails on macOS, the fallback is to keep `:Z` (Fedora needs it) and prove the file mount works with a read inside the container. If that also fails, stop and report rather than drop `:Z`, since `:Z` is an ADR rule.
- **The single-file mount over `local.d/`:** if the entrypoint's `touch local.d/docker.ini` or its admin append fails because of the mount, CouchDB won't start. AC3 catches that. The fallback is mounting the ini at `/opt/couchdb/etc/default.d/` instead, which loads before `local.ini` and still sets `single_node`.
- **Podlet coverage:** `restart:` and `networks:` with `container_name` are mapped in ADR 0001's Evidence, except `restart:`, which is tried in step 4. A podlet failure on an ADR-allowed feature means the compose rules need tightening, so stop and report.
- **The Colima step touches the other engine.** It's limited to one project label and `down -v`, and AC9 proves nothing is left behind. It never runs while the Podman stack is up, because both use port 5984.
- **`couchdb.env` with a real-looking password on disk:** it's throwaway and git-ignored, and deleted in step 8. The secrets guard hook may block writing it. If it does, the owner creates it with `!cp couchdb.env.example couchdb.env`.
- **Considered and rejected:**
  - a compose `healthcheck:` (the image has no curl)
  - mounting the whole `config/` directory over `local.d/` (it hides `docker.ini`)
  - adding the verify step here (0008, high tier)
  - a single `.env` (decided per-service)
- **Recorded during the build:**
  - Order: steps 4, 5 and 7 ran before steps 3 and 6, because the secrets guard hook blocks Claude from creating `couchdb.env`, so the owner creates it. The quadlets were generated with `scripts/check-quadlets --write` (the ADR's podlet command, staged in a temp dir), not a separate podlet call.
  - Podlet does **not** need `couchdb.env` to exist: a run on `compose.yaml` and `config/` alone wrote both files, exit 0. The script still stages the example as `couchdb.env` so that holds if podlet changes.
  - Podlet maps `restart: unless-stopped` to `[Service] Restart=always`, and `mem_limit: 512m` to `Memory=512mb`. It writes no header. The generated names are `couchdb.container` and `liquid-sync.network`, as planned.
  - `podman compose config -q` fails until `couchdb.env` exists, because compose resolves `env_file:` at config time.
- **Overlaps:** `sdlc dep 0002 --check` found none. 0003 builds on `config/` after this item merges.

## Proof
- AC1: `$PODMAN compose config -q` → exit 0. `grep -cE '\$\{|^\s*(include|extends|build|deploy|profiles|scale):' compose.yaml` → `0`. ADR 0001's checklist, ticked against `compose.yaml`, goes in the PR body.
- AC2: `lsof -nP -iTCP:5984 -sTCP:LISTEN` is empty before `up`. After `up`, `$PODMAN port liquid-sync-couchdb` → `5984/tcp -> 127.0.0.1:5984` only.
- AC3: `curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:5984/_all_dbs` → `401`. `curl -s -u "$U:$P" http://127.0.0.1:5984/_all_dbs` includes `"_replicator"` and `"_users"`.
- AC4: `curl -u … -X PUT http://127.0.0.1:5984/ac4probe` → `{"ok":true}`, then `$PODMAN compose down && $PODMAN compose up -d`, then `_all_dbs` still includes `"ac4probe"`.
- AC5: `git check-ignore -q couchdb.env` → 0, `git check-ignore -q couchdb.env.example` → 1, and `git ls-files | grep -E '(^|/)[^/]*\.env$'` is empty.
- AC6: `docker compose up -d`, then AC3's authenticated call succeeds, then `docker compose down -v` → exit 0.
- AC7:
  - `scripts/check-quadlets` → exit 0
  - a scratch copy with `mem_limit: 256m` → non-zero, naming `couchdb.container`
  - a copied quadlet with an unknown key → non-zero from the dry-run
  - `shellcheck -x scripts/check-quadlets` → exit 0
  - `grep -n 'couchdb.env"' scripts/check-quadlets` shows it reading only the `.example` file
- AC8: `grep -rn 'deploy/pi' README.md CLAUDE.md docs` → no output. The README's "Run locally" section contains `podman` and no `docker `.
- AC9: `docker context show` → `colima`. `docker ps -a -q --filter label=com.docker.compose.project=liquid-sync` and `docker volume ls -q --filter name=liquid-sync` are both empty.
- AC10: `sdlc verify` → `verify: PASS`.
- **Rollback:** revert the merge, and run `$PODMAN compose down -v` locally. Only test data is involved.

## Parallel tracks
<!-- None: each step builds on the previous one's files. -->
