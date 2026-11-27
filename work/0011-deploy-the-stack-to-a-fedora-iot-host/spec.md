---
id: 0011
title: Deploy the stack to a Fedora IoT host
stage: spec
from: intent.md
---
# Spec: Deploy the stack to a Fedora IoT host

## Areas of concern
- [x] **`Memory=` breaks the Podman 5.0 floor.** — `compose.yaml`'s `mem_limit: 512m` becomes `Memory=512mb` in `couchdb.container`, and ADR 0001's 1 GB memory budget depends on that key. A dry-run of the committed quadlets on 2026-11-27 failed on Podman 5.0.3, 5.1.2, 5.2.5, 5.3.2 and 5.4.2 with `unsupported key 'Memory' in group 'Container'`, and passed on 5.5.2. With `Memory=` removed, the bundle passes on 5.0.3 (exit 0, no errors), so every other key is fine at 5.0. — Proposed: ask the host side to raise the contract's floor to Podman 5.5. Fedora IoT hosts already run a newer Podman (to be confirmed on the production Pi with `podman --version`). R6 checks the bundle against 5.5. The alternatives are worse. Dropping `mem_limit:` gives up the ADR 0001 budget, and `PodmanArgs=--memory` is banned by the contract. A hand-added `[Service] MemoryMax=` would break the podlet diff. — decided: raise the floor to Podman 5.5. The owner takes this to the host side; ADR 0003 is amended in this item (R10).
- [x] **Should the floor dry-run be a standing check?** — The intent left open whether it runs once during the build or on every verify. It caught a real problem the first time it ran, and a later `compose.yaml` edit or podlet bump could add another newer key. It costs one extra container run per verify (about 1 s once the image is cached). — Proposed: make it a standing step in `check-quadlets`. — decided: run it once, during the build, and record the result in the PR. `verify` stays as it is.
- [x] **The end-to-end proof can't run until the host tool exists.** — The intent's proof is a host tool following the contract bringing CouchDB up on Fedora IoT, but the host side hasn't built that tool. — Proposed: 0011 closes on the bundle checks (R1–R7), plus a local install that does by hand what the host tool will do (AC9). The real run on the production Pi moves to 0005, which already depends on 0011 and is the first live check there. 0005's intent gains that step when this is decided. — decided: as proposed. 0005's intent now carries the first real install.
- [x] **Assumption: the host tool keeps the env file.** — It "removes files a new version drops", and `couchdb.env` sits in the installed quadlet directory but is never in the bundle. If the host tool deletes it, CouchDB starts with no admin. — Proposed: the contract says the host writes `couchdb.env` before any unit starts, so this is assumed to hold. Raise it with the host side as a note, not a blocker. — decided: as proposed.
- [x] **`check-quadlets --write` deletes `deploy/quadlets/`.** — Today `assert_committed` refuses to delete the directory if it holds anything but unit files. The bundle adds `config/` and `couchdb.env.example`. — Proposed: allow exactly the files `--write` itself produces (unit files, `config/*.ini`, `couchdb.env.example`) and still refuse anything else, so a stray file is never deleted silently. — decided: as proposed.

Prior items: 0002 wrote `compose.yaml` and `check-quadlets`. 0003 moved CouchDB config into `config/*.ini` and added the copying entrypoint. 0008 added the verify step and its narrow skip rule (0008 R3, R4). 0016 recorded the contract in ADR 0003. 0016 is merged, so it doesn't block `sdlc start`.

## Requirements
- R1. `deploy/quadlets/` is a complete bundle in the ADR 0003 layout:
  - the podlet-generated unit files;
  - `config/` holding every `config/*.ini` file;
  - `couchdb.env.example`.

  It contains nothing else.
- R2. `config/` and `couchdb.env.example` at the repo root stay the sources of truth. The bundle's copies are byte-identical to them. `compose.yaml` keeps `./config` and `couchdb.env` as its paths, so local `podman compose` and `docker compose` work as before.
- R3. `scripts/check-quadlets --write` regenerates the whole bundle: the unit files and both copies.
- R4. `scripts/check-quadlets` (check mode, run by `sdlc verify`) fails, naming the file, when the bundle differs from a fresh generation. That covers a stale unit file, a stale or missing copy, and an extra file.
- R5. `scripts/check-quadlets` fails, naming the file and the rule, when the bundle breaks a layout rule or a quadlet promise in ADR 0003:
  - (a) a symlink, or anything other than a regular file or directory;
  - (b) a unit file other than `.container`, `.network`, `.volume` or `.pod`, or a non-unit file using a Quadlet unit extension (`.kube`, `.image`, `.build`, `.artifact`);
  - (c) any `PublishPort=` other than exactly `127.0.0.1:5984:5984`, or more than one;
  - (d) any `PodmanArgs=`;
  - (e) a `Network=` that isn't a `.network` file in the bundle;
  - (f) a `.network` file setting `Driver=`, `NetworkInterface=` or `Options=`;
  - (g) an `EnvironmentFile=` other than `couchdb.env`;
  - (h) a `.volume` file without `VolumeName=`;
  - (i) a `.container` without `WantedBy=default.target` under `[Install]`;
  - (j) an `Image=` with no tag, or tagged `latest`.
- R6. The committed bundle is accepted by `quadlet -dryrun -user` at the contract's floor, Podman 5.5. This is checked once, during the build, with the command and output recorded in the PR. It isn't a standing verify step. The existing 6.1.3 dry-run in `check-quadlets` stays.
- R7. The committed bundle passes R4–R6.
- R8. The rules in 0008 R3 and R4 still hold: `--skip-if-no-podman` skips only when Podman is missing or unreachable, and every later failure fails.
- R9. No secret enters the bundle, the check's output or the logs. Only `couchdb.env.example` (fake values) is copied, and the check never reads `couchdb.env`.
- R10. Docs match:
  - README's layout section;
  - ADR 0001's compose rule on relative paths: where the copies live, and that `check-quadlets` keeps them in sync;
  - ADR 0003's Podman floor, amended from 5.0 to 5.5 (dated, 0011), with the evidence.

## Design
**Layout after the change**
```
config/*.ini              # source of truth (unchanged)
couchdb.env.example       # source of truth (unchanged)
compose.yaml              # unchanged
deploy/quadlets/
  couchdb.container       # podlet output
  liquid-sync.network     # podlet output
  config/10-single-node.ini, config/20-livesync.ini   # copies
  couchdb.env.example     # copy
```
`Volume=./config:/liquid-sync/config:ro,Z` and `EnvironmentFile=couchdb.env` already resolve against the unit file's directory. Once installed, both point into the bundle, and the host writes `couchdb.env` there. Quadlet ignores files without a unit extension, so the copies aren't read as units.

**`scripts/check-quadlets`**, restructured around one staged bundle:
1. **Stage.** As today, stage `compose.yaml`, `config/` and the example (as `couchdb.env`) in the temp dir, and run podlet into `out/`. Then add the copies: `cp -R config out/config` and `cp couchdb.env.example out/`. `out/` is now the expected bundle.
2. **Write or diff.** `--write` replaces `deploy/quadlets/` with `out/`. `assert_committed` is widened to the R1 file set; anything else still refuses the delete. Check mode runs `diff -r out deploy/quadlets`, which already reports extra, missing and changed files (R4).
3. **Contract lint (R5).** Runs over the committed `deploy/quadlets/`. It uses `find` for the file rules and line-anchored `grep` on each unit's `Key=value` lines for the promises. Lint errors are collected into the existing `failed` array, so the diff, lint and both dry-runs all report in one run.
4. **Dry-run.** The existing 6.1.3 run. The staging copy becomes `cp -R`, because the bundle now has a subdirectory. The floor check (R6) is a one-off during the build:
   ```
   podman run --rm -v <bundle>:/q:Z -e QUADLET_UNIT_DIRS=/q quay.io/podman/stable:v5.5 /usr/libexec/podman/quadlet -dryrun -user
   ```
   Its output goes in the PR and in ADR 0003's amendment.

The script stays bash with `set -euo pipefail`, shellcheck-clean, and keeps `--help`. The skip logic doesn't change (R8). There are no new dependencies.

**Rollback:** revert the commit. The bundle isn't installed anywhere yet, so nothing on a host changes.

## Acceptance criteria
- AC1 (R1, R3): `scripts/check-quadlets --write` on a clean tree, then `find deploy/quadlets -type f | sort`, lists exactly `couchdb.container`, `liquid-sync.network`, `couchdb.env.example`, `config/10-single-node.ini` and `config/20-livesync.ini`. `git status` shows no other change.
- AC2 (R2): `diff -r config deploy/quadlets/config` and `cmp couchdb.env.example deploy/quadlets/couchdb.env.example` both exit 0. `compose.yaml` is unchanged from main (`git diff --quiet main -- compose.yaml`).
- AC3 (R4): each of these, made in a scratch copy of the repo, makes `scripts/check-quadlets` exit 1 and name the file:
  - an edit to `deploy/quadlets/config/20-livesync.ini`;
  - deleting `deploy/quadlets/couchdb.env.example`;
  - adding `deploy/quadlets/stray.txt`.
- AC4 (R5): a negative test for each rule R5(a)–(j), run by `scripts/test-check-quadlets`. It mutates a temp copy of the bundle, runs the lint only, and expects exit 1 plus the rule's message. The unmutated bundle passes.
- AC5 (R6): the PR records two dry-runs with `quay.io/podman/stable:v5.5`:
  - the committed bundle: exit 0 and no `unsupported key` line;
  - a negative control on `v5.4`: the same bundle fails on `Memory`.
- AC6 (R7): `sdlc verify` ends with `verify: PASS`.
- AC7 (R8): with `PODMAN=/nonexistent`, `scripts/check-quadlets --skip-if-no-podman` exits 0 with the SKIPPED line. With a lint failure and Podman reachable, it exits 1.
- AC8 (R9): `git grep -n` across `deploy/` finds no value from a real env file. The check script never names `couchdb.env` as a read source except as the staged copy of the example (code read).
- AC9 (proof, manual, recorded in the PR): a hand install on the Podman machine, done as the contract's host tool would do it, works:
  - copy `deploy/quadlets/` into a rootless user's `~/.config/containers/systemd/`;
  - write a throwaway `couchdb.env` (mode 0600);
  - run `systemctl --user daemon-reload` and start `couchdb.service`.

  Then `curl -fsS http://127.0.0.1:5984/_up` returns `ok`, and `scripts/check-couchdb-config` (given the throwaway credentials through `COUCHDB_USER` and `COUCHDB_PASSWORD`) prints no MISMATCH. The machine is arm64 with SELinux enforcing on Apple silicon. This is a stand-in for the real run in 0005, not a replacement.
- AC10 (R10): README and ADR 0001 describe the bundle's copies and the sync check (code read).

## Open questions
- [x] How do the `*.ini` files get into `deploy/quadlets/config/`? — From the intent: copied, `config/` stays the source of truth, and `check-quadlets` keeps them in sync (R2–R4).
- [x] Does `couchdb.env.example` ship inside `deploy/quadlets/`? — From the intent: yes, as a synced copy (R1, R2).
- [x] Can 0011 ship without `post-install`? — From the intent: yes. The hook is 0012's.
- [x] Is the Podman floor dry-run a one-time check or a standing step? — decided: once, during the build (R6).

## Standards applied
- sdlc:security-baseline: rule 1, secrets (R9: only the example is copied, and the check never reads the real env file); rule 6, dependencies (no new tool); rule 8, errors (the check fails closed, and the narrow 0008 skip stays).
- CLAUDE.md: bash with `set -euo pipefail`, shellcheck, `--help`; multi-arch images pinned; `*.env` never committed; `compose.yaml` works with both `docker compose` and `podman compose`.
- ADR 0001 (compose rules, podlet as source of truth) and ADR 0003 (the bundle contract).
