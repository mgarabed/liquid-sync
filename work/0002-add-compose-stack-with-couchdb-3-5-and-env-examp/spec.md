---
id: 0002
title: Add compose stack with CouchDB 3.5 and .env.example
stage: spec
from: intent.md
---
# Spec: Add compose stack with CouchDB 3.5 and .env.example

## Areas of concern
- [x] **CouchDB 3.5 doesn't create its system databases.** The image README says CouchDB "no longer autocreates system databases" (`_users`, `_replicator`, `_global_changes`), so a bare stack logs errors and later LiveSync/user setup breaks ([couchdb-docker README](https://github.com/apache/couchdb-docker)). `[couchdb] single_node = true` (added in 3.0.0) creates them at startup ([CouchDB config: couchdb](https://docs.couchdb.org/en/stable/config/couchdb.html)). — Proposed resolution: 0002 adds one small file, `config/10-single-node.ini`. `config/` is bind-mounted read-only at `/liquid-sync/config`, outside `/opt/couchdb`, and an entrypoint override copies its `*.ini` files into `/opt/couchdb/etc/local.d/` before exec'ing the image's `/docker-entrypoint.sh`. `local.d/` itself isn't mounted, because the entrypoint writes the admin to `local.d/docker.ini` on every start. `docker.ini` sorts after `10-…`, so it stays last in the chain and runtime config writes still land in a writable file ([config load order](https://docs.couchdb.org/en/stable/config/intro.html)). 0003 adds its LiveSync settings to `config/` the same way. — decided: single_node ini file. **Changed after acceptance (owner-approved during the build):** the accepted design bind-mounted the file read-only straight into `local.d/`. Under rootless Podman the image's entrypoint runs `find /opt/couchdb … -exec chown -f` under `set -e`; chown fails on the read-only file, so the entrypoint exits 1 with no log output. Dropping `:ro` was rejected because the container would chown the host file to a subuid.
- [x] **Env file layout.** CLAUDE.md says "secrets live in `.env`" and to keep `.env.example` current. With `env_file:` and no interpolation, every key in a service's file is visible inside that container, and 0005's Tailscale auth key must not reach CouchDB. — Proposed resolution: one file per service from the start. `couchdb.env`, committed as `couchdb.env.example`, sits at the repo root next to `compose.yaml`. `.gitignore` gains `*.env` and `!*.env.example`. The CLAUDE.md "Secrets" line and the `.env.example` wording in `docs/project-plan.md` (Phase 1) change to match. The alternative, a single `.env` read only by CouchDB until 0005 splits it, avoids touching CLAUDE.md now but forces a rename later. — decided: per-service env files.
- [x] **Generated quadlet directory name.** `docs/project-plan.md` and the README name `deploy/pi/`, but ADR 0001 says nothing in `deploy/` is specific to the Pi. — Proposed resolution: the generated quadlets live in `deploy/quadlets/`, and the three `deploy/pi/` mentions (README layout, plan component 9 and Phase 5, plan §5.3 procedure) become `deploy/`. Phase 5's host install steps get their own path when that item is written. — decided: `deploy/quadlets/`, with the `deploy/pi/` mentions renamed.
- [x] **CouchDB memory limit.** ADR 0001 caps all liquid-sync containers at 1 GB together, and the archiver's size is unknown until Spike A (0007). — Proposed resolution: `mem_limit: 512m` for CouchDB, which leaves 512 MB for the Tailscale sidecar and the archiver. Raise it later only by an edit that keeps the sum within 1 GB. — decided: 512m.
- [x] **Podlet may need the env file to exist when it generates.** If podlet reads `env_file:` targets, the check would need real secrets. — decided (no owner input needed): the check script runs podlet against a temporary copy of the tree in which `couchdb.env` is copied from `couchdb.env.example`, so it never reads a real secret. The build records whether podlet needs the file at all.
- [x] **No healthcheck.** The 3.5.3 image purges curl after install ([Dockerfile](https://github.com/apache/couchdb-docker/blob/main/3.5.3/Dockerfile)), so a curl healthcheck would always fail. — decided: no `healthcheck:` in 0002. The ACs probe CouchDB from the host. `doctor` (Phase 4) owns ongoing health.
- [x] **`podman` isn't on every shell's PATH.** It's at `/opt/podman/bin/podman` from the `.pkg` installer. — decided: the check script uses `${PODMAN:-podman}` and fails with a message naming that path when the binary isn't found. It doesn't edit any shell profile.
- [x] **Testing `docker compose` touches Colima.** ADR 0001 says local-dev docs and scripts use `podman`, but CLAUDE.md requires `docker compose` to work too. — decided: the build runs one `docker compose up`/`down -v` compatibility check on Colima, the same as ADR 0001's Evidence did, sequentially (never at the same time as the Podman stack, since both use port 5984), and removes the containers and volume afterwards. No docs or scripts use `docker`.
- [x] Dependencies and history: 0006 (merged) produced ADR 0001, whose compose rules, local-development rules and Evidence commands this spec applies. The ADR's "0002 adds the verify step" moves to 0008 (control plane, high tier), and its "0002 must prove `tailscale serve`" moves to 0005. Both are recorded in those items' intents. 0003, 0005 and 0008 already depend on 0002. No other prior work touches these files.

## Requirements
- R1: `compose.yaml` at the repo root defines one service, CouchDB on `docker.io/library/couchdb:3.5`, and meets every item in ADR 0001's compose-rules checklist that applies to a single service. The one Tailscale rule doesn't apply here.
- R2: CouchDB publishes only `127.0.0.1:5984:5984`, and port 5984 is checked free before use.
- R3: CouchDB's data lives in a named volume that survives `podman compose down` and `up` (but not `down -v`).
- R4: CouchDB starts with its system databases present, and with an admin taken from a git-ignored env file.
- R5: A committed example env file lists every variable the stack reads, with placeholder values only, and the real env file is git-ignored.
- R6: The stack comes up and serves CouchDB under both `podman compose` (rootless Podman machine) and `docker compose`.
- R7: Quadlets generated from `compose.yaml` by podlet are committed in the repo.
- R8: A check script regenerates the quadlets with digest-pinned podlet, fails on any difference from the committed ones, and dry-runs them with `quadlet -dryrun -user` in a digest-pinned `quay.io/podman/stable`. It doesn't need real secrets, and it passes `shellcheck`.
- R9: The docs say how to bring the stack up locally with `podman` commands. Repo docs that name the env file or the quadlet directory match the decisions above.
- R10: Colima is untouched afterwards: `docker context show` prints `colima`, and no liquid-sync containers or volumes are left in Docker.

## Design
- **Files**
  - `compose.yaml` (new)
    - `name: liquid-sync`
    - one service, `couchdb`:
      - `image: docker.io/library/couchdb:3.5`
      - `container_name: liquid-sync-couchdb`
      - `networks: [liquid-sync]`
      - `labels: io.containers.autoupdate: registry`
      - `env_file: couchdb.env`
      - `ports: ["127.0.0.1:5984:5984"]`
      - `entrypoint: [/bin/sh, -c, "cp /liquid-sync/config/*.ini /opt/couchdb/etc/local.d/ && exec /docker-entrypoint.sh /opt/couchdb/bin/couchdb"]` (see Areas of concern)
      - `volumes: [couchdb-data:/opt/couchdb/data, ./config:/liquid-sync/config:ro,Z]`
      - `mem_limit: 512m`
      - `restart: unless-stopped`, if podlet maps it. Otherwise it's left out, and quadlet's default applies.
    - top level: `networks: liquid-sync:` and `volumes: couchdb-data:`
  - `couchdb.env.example` (new): `COUCHDB_USER=admin` and `COUCHDB_PASSWORD=change-me`, with a comment that the entrypoint refuses to start without both ([entrypoint](https://github.com/apache/couchdb-docker/blob/main/3.5.3/docker-entrypoint.sh)).
  - `config/10-single-node.ini` (new): `[couchdb]` and `single_node = true`.
  - `deploy/quadlets/*.container`, `*.network` (new, generated): podlet output, with only podlet's own header.
  - `scripts/check-quadlets` (new, bash, `set -euo pipefail`)
    - copies `compose.yaml`, `config/` and `couchdb.env.example` (as `couchdb.env`) into a temp dir
    - runs `ghcr.io/containers/podlet:v0.3.2@sha256:90cb…` with `--file out compose compose.yaml`
    - diffs `out/` against `deploy/quadlets/`, so an added, missing or changed file fails it
    - runs `quay.io/podman/stable:v6.1.3@sha256:1d28…` with `quadlet -dryrun -user` on the committed files
    - `--write` regenerates `deploy/quadlets/` in place, for use after editing `compose.yaml`
    - exits non-zero on any failure, with a one-line reason
    - full digests are copied from ADR 0001's Evidence
  - `.gitignore` (edit): `*.env` and `!*.env.example` added to the Secrets block.
  - `README.md` (edit): a short "Run locally" section (`cp couchdb.env.example couchdb.env`, edit, `podman compose up -d`, `curl -u … http://127.0.0.1:5984/_up`), and the layout block's `deploy/pi/` line.
  - `CLAUDE.md` (edit): the Secrets line names per-service `*.env` files and their `*.env.example`.
  - `docs/project-plan.md` (edit): Phase 1's `.env.example` bullet, plus the `deploy/pi/` mentions (component 9, §5.3, Phase 5).
- **Not changed:** `.sdlc/config.toml`. 0008 wires `scripts/check-quadlets` into `sdlc verify`.
- **Engines:** Colima and the Podman machine are separate VMs with separate storage, so the named volume (`liquid-sync_couchdb-data` under both compose front ends) never moves between engines. That's expected. Data moves only through `backup`/`restore` (Phase 4).
- **Rootless:** the image's entrypoint runs as root inside the user namespace, chowns `/opt/couchdb` to UID 5984, then drops privileges. That works on a rootless named volume. The bind-mounted `config/` is read-only and outside `/opt/couchdb`, so the entrypoint's chown never touches it; the copies in `local.d/` are chowned like any other file there.
- **Rollback:** revert the merge. `podman compose down -v` removes the local stack and its data, which is test data only.

## Acceptance criteria
- AC1 (R1): `podman compose config -q` exits 0. A read of `compose.yaml` against ADR 0001's checklist finds each rule met, recorded as a ticked copy of the checklist in the PR body. `grep -cE '\$\{|^\s*(include|extends|build|deploy|profiles|scale):' compose.yaml` → `0`.
- AC2 (R2): before `up`, `lsof -nP -iTCP:5984 -sTCP:LISTEN` is empty. After `podman compose up -d`, `podman port liquid-sync-couchdb` prints only `5984/tcp -> 127.0.0.1:5984`.
- AC3 (R4): `curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:5984/_all_dbs` → `401`. `curl -s -u "$U:$P" http://127.0.0.1:5984/_all_dbs` lists `_replicator` and `_users`.
- AC4 (R3): after `curl -u … -X PUT …/ac4probe`, `podman compose down`, then `up -d`, the `_all_dbs` call still lists `ac4probe`. Clean up with `down -v`.
- AC5 (R5): `git check-ignore -q couchdb.env` exits 0. `git check-ignore -q couchdb.env.example` exits 1. `git ls-files | grep -E '(^|/)[^/]*\.env$'` is empty. Every variable read by the stack appears in `couchdb.env.example`.
- AC6 (R6): with the Podman stack down, `docker compose up -d` on Colima, then AC3's authenticated call succeeds, then `docker compose down -v` exits 0.
- AC7 (R7, R8): `scripts/check-quadlets` exits 0 on the committed tree. Changing `mem_limit` in a scratch copy makes it exit non-zero and name the differing file. Corrupting a key in a copied quadlet makes the dry-run step exit non-zero. `shellcheck -x scripts/check-quadlets` exits 0. A grep finds no `couchdb.env` (real file) read in the script.
- AC8 (R9): `grep -rn 'deploy/pi' README.md CLAUDE.md docs` → no matches. The README's "Run locally" commands use `podman`, and `grep -n 'docker ' README.md` matches nothing in that section.
- AC9 (R10): `docker context show` → `colima`. `docker ps -a --filter label=com.docker.compose.project=liquid-sync -q` and `docker volume ls -q --filter name=liquid-sync` are both empty.
- AC10: `sdlc verify` → `verify: PASS`.

## Open questions
- [x] Env file layout: one per service, or a single `.env`? — decided: see Areas of concern.
- [x] Quadlet directory: `deploy/pi/` or `deploy/quadlets/`? — decided: see Areas of concern.
- [x] Does CouchDB need single-node setup in this item, or in 0003? — in this item, via `single_node = true`, because the stack isn't "working" without the system databases. See Areas of concern.
- [x] Are the volume and `container_name` stable across `docker compose` and `podman compose`? — the names are the same under both front ends, but the two engines' storage is separate by design (see Design: Engines). Nothing is orphaned that matters, because local data is test data.

## Standards applied
- sdlc:security-baseline:
  - #1: secrets only in git-ignored env files, and the check script never reads them
  - #5: loopback-only, with HTTPS arriving in 0005 through Tailscale
  - #6: no new dependency beyond podlet, already justified in ADR 0001
  - #8: the entrypoint fails closed without an admin
- ADR 0001: the compose rules, the local-development rules, the memory budget, and the digest-pinned tooling.
- CLAUDE.md:
  - compose works with both engines
  - multi-arch, pinned images
  - secrets in `.env`-style git-ignored files with a current example
  - bash with `set -euo pipefail` and shellcheck
  - never expose CouchDB on a public interface
- No stack skill applies (stack `generic`), and there are no repo-local skills.
