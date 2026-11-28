---
id: 0018
title: Run test/*.sh in sdlc verify
stage: spec
from: intent.md
---
# Spec: Run test/*.sh in sdlc verify

## Areas of concern
- [ ] **A test that hangs stalls verify.** `sdlc verify` waits on each step with no timeout, and macOS has no `timeout` without coreutils (installing it needs the owner's OK, per 0008's Risks). — A hung test blocks every verify until someone presses Ctrl-C. — Accept it: run each test with stdin from `/dev/null`, so a test can't wait on input, and print each test's name before it runs, so the hung one is obvious. No timeout.
- [ ] **Every verify now runs every test, on the dev Mac.** Today's only test is safe: a stub podman, a closed port, its own temp dir. A later test that touches the real stack, `couchdb.env` or a real vault would run on every verify. — That's a convention, not something the runner can enforce. — Write the rule into CLAUDE.md's Testing section (R6), so each later item's spec and review checks against it.
- [ ] **Changing `[verify] steps` voids recorded verifies.** `sdlc_core.verify_steps_hash` hashes each step's name, run and fast fields. — Every checkout's last pass goes stale once this merges. That's expected, and the same as 0008. — None needed; the first verify after merge records a new pass.
- [ ] **No remote CI.** In github review mode, nothing runs verify on the PR. — The tests only guard as well as local verify does. — Out of scope by the intent; a separate item if wanted.

History: 0008 added the `quadlets` step, the only earlier `config.toml` verify edit. It rejected a `test/` harness then as "a separate decision", and this is that item. 0012 added `test/liquid-sync-init.sh` and ran it by hand.

## Requirements
- R1. `sdlc verify` runs every `test/*.sh` (top level of `test/` only; `test/fixtures/` and other subdirectories are never run), in name order, from the repo root.
- R2. The step fails if any test exits non-zero. The output names each failing test and its exit code.
- R3. The step fails if any `test/*.sh` isn't executable, naming the file. It is reported, not silently skipped or run some other way.
- R4. With no `test/*.sh` at all, the step passes and says that no tests were found.
- R5. Each test runs with stdin from `/dev/null`. Its name is printed before it starts, and its own output is shown.
- R6. CLAUDE.md's Testing section says how to add a test (an executable `test/<name>.sh`, exit 0 on pass) and that a test must be safe to run at any time: no real env file, no real vault, no change to the running stack, fake credentials only.
- R7. Adding a new test needs no edit to `.sdlc/config.toml` or any other control file.
- R8. The step works on macOS (bash 3.2, BSD tools) and Linux, and runs under `--fast` too.

## Design
- **The runner: `scripts/run-tests [DIR]`** (new, bash, `set -euo pipefail`). DIR defaults to `test` under the repo root. It:
  - lists `DIR/*.sh` with a bash glob under `nullglob`. Glob order is sorted, which gives R1's name order. No `find`, so subdirectories are never seen;
  - with none, prints `run-tests: no tests in DIR` and exits 0 (R4);
  - for each file: if it's not executable, prints `FAIL <file>: not executable` and counts a failure (R3). Otherwise prints `── <file>`, runs `"$file" </dev/null` with `cd` at the repo root, and on non-zero exit prints `FAIL <file> (exit N)` (R2, R5);
  - ends with `run-tests: N passed, M failed` and exits 1 if M > 0.
  - The DIR argument exists so the runner can be tested against a temp directory of fake tests.
- **The verify step** (`.sdlc/config.toml`, after `quadlets`): `{ name = "tests", run = "scripts/run-tests" }`. No `fast` key: `sdlc verify --fast` runs a step's `fast` command when it has one and its `run` otherwise (`sdlc_cli.py`), so the tests run under `--fast` as well. The whole suite takes about 5 s today (R8).
- **The runner's own test: `test/run-tests.sh`** (new). It builds a temp directory under `/tmp` with fake tests (pass, fail with exit 3, not executable, a subdirectory holding a failing test, one that reads stdin) and runs `scripts/run-tests` on it. It checks the output and exit code for each case, plus the empty-directory case. It runs the runner only on its temp dirs, never on `test/`, so it doesn't recurse. Cleanup follows the guarded `rm -rf` in `test/liquid-sync-init.sh`.
- **Docs:** CLAUDE.md's Testing section gains R6's bullet. ADRs aren't affected.
- **Shellcheck:** the existing step already picks up both new files by their shebangs.
- **Rollback:** revert the merge. Removing the `tests` line from `config.toml` alone also turns the step off; the runner and tests are inert without it.

## Acceptance criteria
- AC1 (R1, R2, R3, R4, R5): `test/run-tests.sh` passes. It covers:
  - a passing test, which shows its output;
  - a failing one, named with `exit 3`;
  - a non-executable one, named, which fails the run;
  - a failing test in a subdirectory, which is never run;
  - a stdin-reading test, which gets EOF and doesn't hang;
  - an empty directory, which passes with "no tests";
  - the overall exit code, 1 with any failure and 0 without.
- AC2 (R1, R8): `sdlc verify` and `sdlc verify --fast` both show a `tests` step that runs `test/liquid-sync-init.sh` and `test/run-tests.sh`, and end with `verify: PASS`.
- AC3 (R2): manual, in the build worktree. A temporary `test/zz-fail.sh` containing `exit 1` makes `sdlc verify` fail at the `tests` step and name the file. Deleted again before commit; the PR records the output.
- AC4 (R6): `grep` finds the new rule in CLAUDE.md's Testing section.
- AC5 (R7): the branch diff touches `.sdlc/config.toml` once, adding the one step. Adding AC3's temporary test needed no config edit.
- AC6: `shellcheck -x scripts/run-tests test/run-tests.sh` is clean (the shellcheck step).

## Open questions
- [x] Does the step run in `--fast` too? — Yes. verify runs every step under `--fast`, using a step's `fast` command only as a substitute, and the suite takes about 5 s (Design).
- [ ] Inline the loop in `config.toml`, or a runner script? — Proposed: `scripts/run-tests`. It keeps the control file at one stable line, passes shellcheck, and can be tested itself. An inline loop would need a high-tier item for every change to it.
- [ ] Stop at the first failure, or run every test and report all failures? — Proposed: run all, then fail. One run shows every broken test, and the suite is small.

## Standards applied
- sdlc:security-baseline: fake credentials only in tests and fixtures (rule 1); fail closed, so a non-executable test fails rather than skips (rule 8). No new dependencies (rule 6).
- CLAUDE.md: bash with `set -euo pipefail` and shellcheck; no `rm` outside `/tmp`; requirement references written as `0018 R3`.
