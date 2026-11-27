---
id: 0012
title: Add liquid-sync init
stage: plan
from: spec.md
---
# Plan: Add liquid-sync init

## Files that change
- `lib/common.sh` (new) — the shared helpers: `die`, `warn`, `info`, `env_value`, `curl_auth_line`, `couch_get`, `podman_bin` and `wait_for_couch`. It's sourced, not executed, but has a `#!/usr/bin/env bash` line so the shellcheck verify step finds it.
- `scripts/check-couchdb-config` (edit) — source `lib/common.sh` in place of its own `die`, `env_value`, `escape` and `curl_auth`. Behaviour is identical (0012 R11).
- `liquid-sync` (new, executable) — the CLI entry point: root resolution, global flags, dispatch, and `cmd_init`.
- `test/liquid-sync-init.sh` (new, executable) — the tests for 0012 AC1–AC5 and AC7. Self-contained, needs no Podman, and uses fake credentials only.
- `.gitignore` (edit) — ignore `.couchdb.env.*`, init's temp file, as a backstop to its cleanup trap.
- `README.md` (edit) — mark `init` as available in "Planned CLI", with one line on what it does.
- `docs/project-plan.md` (edit) — the Phase 2 init line: local only; it generates the env file, starts the stack, waits and checks for drift.
- `docs/decisions/0003-host-bundle-contract.md` (edit) — dated amendment (2026-11-27, 0012) to the `post-install` bullet. It's optional and not shipped yet; health is 0017's, drift is 0015's, and init is local only.
- `docs/runbooks/local-sync-test.md` (edit) — "Before you start" uses `./liquid-sync init`.
- `work/done/0012-add-liquid-sync-init/plan.md` (edit) — tick steps as they land.

## Order of work
- [x] 1. **Record a baseline for `check-couchdb-config`.** The build runs in `.worktrees/0012`, which has no git-ignored env file. So capture stdout, stderr and exit code from the **main checkout's** copy, by absolute path (`/Users/mike/src/liquid-sync/scripts/check-couchdb-config`):
  - a normal run against the local stack (it reads its own env file, and its output has no secrets);
  - `--help`;
  - an unknown argument;
  - fake `COUCHDB_USER=x COUCHDB_PASSWORD=y`, which expects the 401 message.

  Save them under `/tmp/0012-baseline/` for 0012 AC8. If the stack isn't up, ask the user to start it from the main checkout. Nothing is committed in this step.

  *As built:* the main checkout had no `couchdb.env` and no stack was running, so only `--help`, the unknown argument and fake credentials with no stack (`can't reach CouchDB`) could be captured here. The normal run and the 401 case moved to step 6: `main`'s copy of the script goes into `/tmp/0012-baseline/tree/scripts/`, beside a copy of `config/` and a symlink to the worktree's `couchdb.env`, so it reads the same env file and config as the worktree's copy.
- [x] 2. **`lib/common.sh`, and move `check-couchdb-config` onto it.**
  - Move `die`, `env_value`, `escape` and `curl_auth` as they are into the lib. `env_value` takes the file as its first argument, and `curl_auth_line USER PASS` returns the line.
  - Add `couch_get URL PATH [curl args]`, which sends credentials on curl's stdin (`--config -`), with `--max-time 10`.
  - Add `podman_bin`, which echoes `$PODMAN`, else `podman` on `PATH`, else `/opt/podman/bin/podman`.
  - Add `wait_for_couch URL TIMEOUT`, which polls `/_up` every 2 s and returns 1 on timeout. On 401 or 403 it fails at once with "CouchDB refused the admin credentials", so a container still running on an older password doesn't look like a 60 s timeout.
  - The lib sets nothing at source time apart from functions, and starts with a guard against being executed directly. Callers source it with a `# shellcheck source=lib/common.sh` directive above the `source "$root/lib/common.sh"` line, because `shellcheck -x` can't follow a non-constant path.
  - In `check-couchdb-config`, keep the prefix `check-couchdb-config:` on its `die` messages by setting `PROG` before sourcing.
  - Re-run `--help`, the unknown argument and the fake-credentials case with the worktree's copy, and `diff` them against step 1's output; they must be identical. The fake-credentials case exercises the moved curl path early. The normal run is compared in step 6, once init has the stack up. Run `sdlc verify --fast`.
- [x] 3. **Write the tests first:** `test/liquid-sync-init.sh`.
  - Use `mktemp -d` under `/tmp`, guarded like `check-quadlets`' `assert_tmp`. Copy `liquid-sync`, `lib/` and `scripts/check-couchdb-config` in, plus a fake `couchdb.env.example` (`COUCHDB_USER=admin`, `COUCHDB_PASSWORD=`, one comment line).
  - Add a stub `PODMAN`: a script that appends its argv to `calls.log` and exits 0.
  - Set `COUCHDB_URL=http://127.0.0.1:9` (a closed port) and `LIQUID_SYNC_TIMEOUT=3`.
  - Cases:
    - AC1: dispatch, `--help` and exit codes.
    - AC2: the file is created with mode 600, keeps the example's lines, has a 32-character password, and the password isn't in the captured output. init exits 1 here, at the wait step; that's expected and asserted.
    - AC3: an existing canary file keeps its checksum, mode and mtime. A 0644 file gets a warning and stays 0644.
    - AC4: two fresh runs give different passwords, and a pre-created target leaves no temp file.
    - AC5: `--dry-run` creates no file and makes no stub call.
    - AC7: the timeout fires in under 10 s, with the URL in the message and no canary.
  - Each case prints `ok <name>` or `FAIL <name>: why`, and the script exits 1 on any FAIL. Commit it along with step 4. Running it now fails, because `liquid-sync` doesn't exist yet.
- [x] 4. **`liquid-sync` and `cmd_init`,** following the 0012 spec's Design:
  - Parse flags: `--help`, `-h` and `--dry-run` work anywhere after the subcommand, and `--help` also works before it. No arguments prints the help.
  - Env step: `[ -e ]` check, then the mode check with a portable `stat`: `stat -f %Lp` on macOS, `stat -c %a` on Linux, picked by trying one and falling back. Then generation under a `umask 077` subshell, writing a `mktemp "$root/.couchdb.env.XXXXXX"` file, then `ln` into place and `rm` the temp. A trap removes the temp file on error.
  - Then the compose up, the wait and the drift check.
  - Run `bash test/liquid-sync-init.sh` until it's green, then run `sdlc verify --fast`.
- [x] 5. **Docs:** the README, the project plan, the ADR 0003 amendment and the runbook, as listed above.
- [x] 6. **Manual run (0012 AC6), in the worktree.** The worktree has no env file, which is exactly the first-run case, so nothing needs moving.
  - Tell the user first: this briefly takes over the local dev stack. Compose recreates the `liquid-sync-couchdb` container on the worktree's new password and `config/` mount. The data volume stays.
  - Run `./liquid-sync init` twice, then `git status --short`.
  - For 0012 AC8, run the worktree's `scripts/check-couchdb-config` (now reading the worktree's new env file) and `diff` it against step 1's normal-run baseline. Only `N settings match` lines are compared, and they hold no secrets.
  - Restore: from the main checkout, run `podman compose up -d` (it recreates the container on the main env file and mount), then the main checkout's `scripts/check-couchdb-config`.
  - No `-v` anywhere: the admin is written to `local.d/docker.ini` from the env file when the container is created, not stored in the data volume.

  Record both init transcripts in the PR, which contain no secrets by R5. The worktree's env file is deleted along with the worktree.

  *As built:* no stack was running and the main checkout has no env file (see step 1), so nothing was taken over, and the normal-run and 401 baselines came from `main`'s copy in `/tmp/0012-baseline/tree/`. The restore is `podman compose down` (no `-v`) from the worktree. It runs in step 7, after the verifier, which may need the stack up. That stops and removes the container and network. The `liquid-sync_couchdb-data` volume that step 6 created stays, since nothing here deletes data. The user accepted this departure from 0012 AC6's restore clause on 2026-11-27, and spec.md is unchanged.
- [x] 7. **Close out.** Run `sdlc verify` (full) and paste the summary line. Run `bash test/liquid-sync-init.sh` and paste its output in the PR, since verify doesn't run it until 0018. Then run the `sdlc:verifier` agent and submit.

## Risks
- **The riskiest step is 2,** moving `check-couchdb-config` onto the lib. It's the only script that handles the admin password today, and 0011's AC9 and the runbook use it. A subtle change (quoting in `env_value`, curl's stdin, the `die` prefix) could break it, or leak the password into argv. Mitigations:
  - the step 1 baseline diff;
  - moving the functions verbatim;
  - a code read that every curl call still uses `--config -`.
- **The secrets guard blocks the agent on the real env file.** The tests use a temp copy with fake values, and the manual run uses the worktree's own fresh file, read only by the scripts. The build must never `cat`, `grep` or source `couchdb.env` itself.
- **Step 6 takes over the local stack.** If the restore is skipped, the dev stack runs on the worktree's password, and the worktree's env file disappears with the worktree. The restore is a numbered sub-step, and step 7's close-out checks the main checkout's `check-couchdb-config` passes.
- **The password pipeline under `pipefail`.** `head -c 48 /dev/urandom | base64 | tr -dc … | cut -c1-32` has finite stages, so nothing gets SIGPIPE. Asserting a 32-character result catches a short read. Avoid `tr … </dev/urandom | head`: it gets SIGPIPE, and `pipefail` turns that into a failure.
- **`stat` differs between macOS and Linux.** Handled with a fallback, and the test checks the mode on the Mac where it runs.
- **macOS bash 3.2.** `/usr/bin/env bash` may be 3.2 on the Mac. Avoid `mapfile`, `${var,,}`, associative arrays and process substitution that feeds curl (the runbook notes 3.2 closes it early).
- **A temp file left in the repo root.** It's named `.couchdb.env.XXXXXX`, which `*.env` in `.gitignore` doesn't match. The trap removes it, but add `.couchdb.env.*` to `.gitignore` as a backstop. That adds `.gitignore` (edit) to the files that change.
- **Rejected:**
  - Sourcing `couchdb.env` to read it: it would execute the file.
  - `openssl rand`: one more tool, where coreutils is enough.
  - A generic `*_PASSWORD=` filler for every `*.env.example`: there's only one service, so a later service adds its own rule.
  - Running the tests from `check-quadlets`, as 0011 did with its lint tests: unrelated coupling, and 0018 is the clean fix.
- **Prior items:**
  - 0003 wrote `check-couchdb-config`. Its stdin-curl pattern and its "parsed, never sourced" rule carry into the lib.
  - 0011 established the control-file tier rule, which is why the tests wait for 0018.
- **Overlaps:** see `sdlc dep 0012 --check`. 0013–0015 will extend `liquid-sync` and `lib/common.sh`, so 0012 builds first. 0018 touches only `.sdlc/config.toml`, so either order works.

## Proof
- AC1–AC5, AC7: `bash test/liquid-sync-init.sh` prints `ok` for each case and exits 0.
- AC6: step 6's transcripts in the PR. The first run shows `couchdb.env created (mode 0600)`, `check-couchdb-config: N settings match` and `init: done`. The second shows every step already in place. `git status --short` is empty.
- AC8: `diff` of the step 1 baselines against the worktree copy's output: `--help`, the unknown argument and fake credentials in step 2, and the normal run in step 6. Every diff is empty.
- AC9: `sdlc verify` ends with `verify: PASS`, and the shellcheck step lists `liquid-sync`, `lib/common.sh` and `test/liquid-sync-init.sh` among the checked files (`git ls-files` after `git add`).
- AC10: a code read of the README, project-plan, ADR 0003 and runbook diffs.
- Finally `sdlc verify`, which must end with `verify: PASS`.

## Parallel tracks
None. Steps 2–4 share `lib/common.sh`.
