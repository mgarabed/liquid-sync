---
id: 0012
title: Add liquid-sync init
stage: spec
from: intent.md
---
# Spec: Add liquid-sync init

## Areas of concern
- [x] **The tests can't join `sdlc verify` without the high tier.** — `.sdlc/config.toml` is a control file, and editing it forces the high tier (0011 hit this and worked around it). `init`'s tests that need no Podman, such as env-file generation, never overwriting and no secret in output, would then run only by hand. — Proposed: a separate small item at the high tier adds one generic verify step, `tests`, which runs every executable `test/*.sh`. 0012 and every later item then add tests with no control edit. 0012 ships its tests in `test/` and records a manual run in its PR (`bash test/liquid-sync-init.sh`). If that item merges first, verify picks them up. The alternative is re-tiering 0012 to high for one config line. — decided: separate item, captured as 0018. 0012 doesn't depend on it.
- [x] **Shared helpers vs the existing script.** — `scripts/check-couchdb-config` already has env parsing (`env_value`, which doesn't source the file), the curl stdin-auth line (`escape`, `curl_auth`) and `die`. The CLI needs the same code, and 0013–0015 need it too. — Proposed: answer the intent's open question with a sourced `lib/common.sh`, and move `check-couchdb-config` onto it in this item. That leaves one copy of the secret-handling code. Its behaviour and output must stay identical (R11), and 0011's `check-quadlets` is untouched. — decided: as proposed.
- [x] **Which characters the password may use.** — `couchdb.env` is read three ways: by compose's `env_file` (which interpolates `$` in values), by systemd's `EnvironmentFile=` (quoting rules), and by curl config strings (which need `"` and `\` escaped). — Proposed: 32 characters from `[A-Za-z0-9]`, about 190 bits, written unquoted. All three readers agree on it. — decided: as proposed.
- [x] **Assumption: `podman compose` works on the dev Mac.** — ADR 0001 notes that `podman compose` delegates to `docker-compose` when it's installed. — Proposed: init calls `"$PODMAN" compose up -d`, with `PODMAN` defaulting the way `check-quadlets` does (`podman` on `PATH`, else `/opt/podman/bin/podman`). It never calls `docker`, and if Podman can't reach an engine it fails and says so. It never changes Docker contexts. — decided: as proposed.

Prior items:
- 0003 wrote `scripts/check-couchdb-config` and the `.ini` config that init only checks.
- 0002 wrote `couchdb.env.example`. Its empty password is deliberate: the image refuses to start without one.
- 0006 (ADR 0001) set the local Podman and Colima rules.
- 0011 shows the control-file tier rule (above).
- 0016 and 0011 are merged, so nothing blocks `sdlc start`.

## Requirements
- R1. `./liquid-sync` at the repo root runs subcommands:
  - `./liquid-sync --help`, or no arguments, lists them with one line each and exits 0;
  - an unknown subcommand prints the list to stderr and exits 2;
  - `./liquid-sync <cmd> --help` prints that subcommand's usage and exits 0.
- R2. `--dry-run` is a shared flag that every changing subcommand accepts. With it, init changes no file and starts nothing.
- R3. When `couchdb.env` is missing, `init` creates it from `couchdb.env.example`:
  - every line is kept, except that the `COUCHDB_PASSWORD=` value becomes a fresh random password: 32 characters from `[A-Za-z0-9]`, read from `/dev/urandom`;
  - the file has mode 0600 from the moment it exists;
  - it appears complete or not at all.
- R4. When `couchdb.env` already exists, init doesn't change its content, mode or mtime, and doesn't recreate it. It reports that the file exists. If the mode is looser than 0600, init warns, but still doesn't change the file.
- R5. Neither the generated password nor any value from `couchdb.env` appears in stdout, stderr, argv of any child process, or any file other than `couchdb.env` itself.
- R6. init starts the stack with `podman compose up -d` and never uses `docker`.
- R7. init waits until an authenticated `GET /_up` on `127.0.0.1:5984` returns 200, up to a timeout (default 60 s, `LIQUID_SYNC_TIMEOUT` overrides it). On timeout it exits 1 with a message naming CouchDB and the URL, and no credentials.
- R8. init then runs the config drift check and exits non-zero if it finds drift.
- R9. A second `init` on a working stack changes no file, reports each step as already in place, and exits 0.
- R10. `--dry-run` prints each step init would take, such as "would create couchdb.env", and exits 0.
- R11. `scripts/check-couchdb-config` behaves exactly as before: same arguments, output lines and exit codes. It now uses the shared helpers.
- R12. Every new or changed script is bash with `set -euo pipefail` and passes the existing shellcheck verify step.
- R13. Docs:
  - README's "Planned CLI" section marks `init` as available and describes what it does;
  - `docs/project-plan.md`'s Phase 2 init line matches this spec;
  - ADR 0003's `post-install` bullet no longer says it's init (dated amendment, 0012);
  - `docs/runbooks/local-sync-test.md`'s "Before you start" uses `./liquid-sync init`.

## Design
**Files**
- `liquid-sync` (new, executable): resolves the repo root from its own path, sources `lib/common.sh`, parses global flags (`--help`, `--dry-run`), and dispatches `init` to `cmd_init`. Later items add `cmd_vault` and the others in the same file, or in `lib/cmd-*.sh` once it grows. That's a later item's call.
- `lib/common.sh` (new, sourced, not executable):
  - `die`, `warn` and `info`;
  - `env_value FILE KEY` (moved from `check-couchdb-config`, never sources the file);
  - `curl_auth_line USER PASS` (the escaped curl `user =` line);
  - `couch_get URL PATH`, which sends credentials on curl's stdin (`--config -`);
  - `podman_bin`;
  - `wait_for_couch URL TIMEOUT`.
- `scripts/check-couchdb-config` (edit): sources `lib/common.sh`, with no change in behaviour.

**init flow**
1. **Env file.** If `couchdb.env` exists, check its mode and report. Otherwise:
   - generate the password with `head -c 48 /dev/urandom | base64 | LC_ALL=C tr -dc 'A-Za-z0-9' | cut -c1-32`. Every stage reads finite input, so nothing gets SIGPIPE under `pipefail`. Check that the result is exactly 32 characters, or die;
   - under `umask 077`, write the example to a `mktemp` file in the repo root, with the `COUCHDB_PASSWORD=` line replaced;
   - link it into place with `ln` (atomic, and fails if the target exists), then remove the temp file. A concurrent creator wins, and init then reports the file as existing.

   The password lives only in a shell variable and the file. It's written with `printf` to the temp file and never echoed.
2. **Start** with `"$(podman_bin)" compose up -d`, run from the repo root. Compose's own output passes through; it doesn't print env values.
3. **Wait.** `wait_for_couch` polls `/_up` every 2 s with credentials on stdin.
4. **Check.** Run `"$root/scripts/check-couchdb-config"` and pass its exit code through.

`--dry-run` stops after reporting each step's decision. Step 1 still inspects whether the file exists, but writes nothing, and steps 2–4 are reported only.

**Output:** one line per step, such as `init: couchdb.env created (mode 0600)` or `init: couchdb.env exists, left as is`, then `init: done`. Errors go to stderr, prefixed `liquid-sync:`.

**Tests:** `test/liquid-sync-init.sh` (new, executable bash) runs against a temp copy of the repo's scripts, with a fake `couchdb.env.example`. A stub `PODMAN`, plus `COUCHDB_URL` pointing at a closed port, keeps it from starting anything real. It covers R3, R4, R5 (a canary password must not show up in captured output), R10 and the R1 dispatch and exit codes. R6–R9 against a real stack are a manual run in the PR.

**Rollback:** revert. The only state init creates is a local, git-ignored `couchdb.env`, which can be deleted by hand.

## Acceptance criteria
- AC1 (R1): `./liquid-sync --help` exits 0 and lists `init`. `./liquid-sync bogus` exits 2. `./liquid-sync init --help` exits 0. All three are covered by `test/liquid-sync-init.sh`.
- AC2 (R3, R5): in the test, `init` with no env file creates one with mode `600` (`stat`). The file keeps every non-password line of the example, and its password matches `^[A-Za-z0-9]{32}$`. The password string doesn't appear in captured stdout or stderr.
- AC3 (R4): in the test, a pre-existing env file with a canary password keeps its checksum, mode and mtime across `init`, and the canary isn't in the output. A 0644 file gets a warning and stays 0644.
- AC4 (R3): two runs on a fresh copy give two different passwords. With the `ln` target pre-created, the temp file is cleaned up.
- AC5 (R2, R10): `init --dry-run` with no env file prints "would create" and leaves no env file or temp file, and the stub `PODMAN` logs no call.
- AC6 (R6–R9, manual, PR transcript): on the dev Mac, with `couchdb.env` moved aside, the first `./liquid-sync init` creates it, brings the stack up and prints `check-couchdb-config: N settings match` and `init: done`. A second run reports every step as already in place, and `git status --short` is clean. Put `couchdb.env` back afterwards.
- AC7 (R7): in the test, a `COUCHDB_URL` pointing at a closed port with `LIQUID_SYNC_TIMEOUT=3` exits 1 in about 3 s, with a message naming the URL and no credentials.
- AC8 (R11): before and after the change, against the running local stack, `scripts/check-couchdb-config` gives identical output and exit code, plus `--help` and an unknown argument (exit 1).
- AC9 (R12): `sdlc verify` ends with `verify: PASS`, and shellcheck covers `liquid-sync`, `lib/common.sh` (through `-x`) and the test.
- AC10 (R13): a code read of the four doc changes.

## Open questions
- [x] Is post-install a wrapper or a separate script? — From the intent: no post-install hook in this item.
- [x] How does init tell local from host? — From the intent: init is local only.
- [x] What counts as a migration? — From the intent: none yet.
- [x] What username does a generated env file get? — From the intent: the example's.
- [x] One script file, or `./liquid-sync` plus a sourced `lib/`? — decided: a sourced `lib/common.sh`, with `check-couchdb-config` moved onto it.

## Standards applied
- sdlc:security-baseline:
  - rule 1, secrets: R3–R5, mode 0600 from creation, credentials only on curl's stdin, a canary test;
  - rule 6, dependencies: none added, only coreutils, curl and podman;
  - rule 8, errors: fail closed on timeout or drift, and messages without secrets.
- CLAUDE.md: bash with `set -euo pipefail`, shellcheck, idempotent, `--help`, `--dry-run`; secrets in git-ignored `*.env` files with the example kept current; test against a throwaway setup only.
- ADR 0001: local Podman and Colima rules, and `podman` commands only.
- ADR 0003: the host writes the env file, so init stays off hosts.
