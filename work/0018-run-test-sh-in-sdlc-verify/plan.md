---
id: 0018
title: Run test/*.sh in sdlc verify
stage: plan
from: spec.md
---
# Plan: Run test/*.sh in sdlc verify

## Files that change
- `scripts/run-tests` (new) — the runner: runs every top-level `DIR/*.sh` (DIR defaults to `test`), runs them all, reports each failure and any non-executable file, and exits 1 if any failed (0018 R1–R5, R8).
- `test/run-tests.sh` (new) — the runner's own test, against temp dirs of fake tests (0018 AC1).
- `.sdlc/config.toml` (edit) — one step, `{ name = "tests", run = "scripts/run-tests" }`, after `quadlets` (0018 R7).
- `CLAUDE.md` (edit) — the Testing section: how to add a test, and the rule that tests must be safe to run at any time (0018 R6).
- `work/0018-run-test-sh-in-sdlc-verify/plan.md` (edit) — ticks and any departures.

## Order of work
- [x] 1. **Write `test/run-tests.sh` first**, mode 0755, bash with `set -euo pipefail`. Follow `test/liquid-sync-init.sh`'s shape:
  - `here` is the repo root. `tmp="$(mktemp -d /tmp/run-tests-test.XXXXXX)"`, with the same `assert_tmp` case-guard before the `trap ... rm -rf "$tmp"` (only `/tmp/run-tests-test.?*` may be deleted);
  - `ok` and `fail` helpers print `ok <case>` or `FAIL <case>: why`, and the script exits with the failure flag;
  - a `run DIR` helper runs `"$here/scripts/run-tests" DIR`, capturing stdout+stderr into `$tmp/out` and the exit code into `rc`, with `set +e` around it.

  Cases, each building its own dir under `$tmp` (cite `0018 AC1` in a header comment):
  - **pass:** `a.sh` echoes `hello-a` and exits 0. Expect rc 0, `hello-a` in the output, a `── ` line naming `a.sh`, and `1 passed, 0 failed`.
  - **fail:** `a.sh` passes, `b.sh` exits 3, `c.sh` passes. Expect rc 1, `FAIL` naming `b.sh` with `exit 3`, and `c.sh` still ran (its marker is in the output): run-all, not stop-first.
  - **not executable:** `a.sh` mode 0644. Expect rc 1 and `FAIL` naming `a.sh` with `not executable`, and its marker absent (it wasn't run).
  - **subdirectory:** `sub/x.sh`, executable, exits 1, plus a passing `a.sh`. Expect rc 0 and `sub/x.sh`'s marker absent.
  - **stdin:** `a.sh` runs `cat` and then echoes `stdin-eof`. Expect rc 0 and the marker present. Run the runner with its stdin from a file holding `leak-marker`. Expect `leak-marker` absent from the output, which only holds if the runner gives each test `/dev/null` rather than its own stdin. This checks without any risk of hanging.
  - **empty:** an empty dir. Expect rc 0 and `no tests` in the output.
  - **cwd:** `a.sh` prints `$PWD`. Expect the repo root, resolved with `pwd -P`, even when the runner is started from `$tmp`.

  The test fails at this point, since the runner doesn't exist. Don't commit yet; go straight to step 2, so the tree stays green.
- [x] 2. **Write `scripts/run-tests`**, mode 0755, bash with `set -euo pipefail`:
  - `root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"`. Resolve DIR (default `$root/test`) to an absolute path *before* `cd "$root"`; exit 2 with a message if DIR isn't a directory. `--help` prints one usage line and exits 0.
  - `shopt -s nullglob`, then `for f in "$dir"/*.sh`. No arrays: bash 3.2 (macOS) errors on an empty `"${arr[@]}"` under `set -u`. Count with integers instead.
  - For each file, print it relative to the root when it's under the root. If `[ ! -x "$f" ]`, print `FAIL <f>: not executable` and count a failure. Otherwise print `── <f>`, run `"$f" </dev/null` inside `if`, so `set -e` doesn't stop the loop, and on a non-zero exit print `FAIL <f> (exit N)`.
  - With zero files, print `run-tests: no tests in <dir>` and exit 0. Otherwise end with `run-tests: P passed, F failed` and exit 1 if F > 0.
  - A short comment on the `</dev/null` and the non-executable check, citing 0018 R5 and R3, since both are guards someone might otherwise tidy away.
  - Run `test/run-tests.sh` (all `ok`), then `scripts/run-tests` itself (both tests pass), then `sdlc verify --fast`. Commit steps 1 and 2 together.
- [x] 3. **Wire the step into `.sdlc/config.toml`.** This is the high-tier step. Add `{ name = "tests", run = "scripts/run-tests" },` as the last entry of `[verify] steps`, with no `fast` key. Change nothing else in the file. Then run `sdlc verify` and `sdlc verify --fast`. Both must show the `tests` step running both test files and end with `verify: PASS` (0018 AC2). Commit on its own, so a rollback can revert just this commit.
- [x] 4. **AC3, by hand.** Create `test/zz-fail.sh` with `#!/usr/bin/env bash` and `exit 1`, mode 0755. Run `sdlc verify --fast` and save the output to `/tmp/0018-ac3.txt`. It must fail at the `tests` step and name `test/zz-fail.sh`. Move it out with `mv test/zz-fail.sh /tmp/0018-zz-fail.sh` (it was never tracked, and nothing outside `/tmp` is deleted), then confirm `git status --short` is clean. Nothing is committed in this step; the output goes in the PR.
- [x] 5. **Docs: CLAUDE.md's Testing section.** Add a bullet after the existing two:
  - "Script tests are executable `test/<name>.sh` files that exit 0 on pass. `sdlc verify` runs every one through `scripts/run-tests`, so adding a test needs no config edit. A test runs on every verify, so it must be safe at any time: its own temp dir, fake credentials only, never the real env file, a real vault or the running stack."

  Run `sdlc verify --fast` and commit.
- [ ] 6. **Close out.** Run a full `sdlc verify` and paste the summary line. Check `git diff main --stat -- .sdlc/config.toml` shows exactly one added line (0018 AC5). Run the verifier agent, then submit. The PR body includes AC3's output and the rollback note from Proof.

## Risks
- **Riskiest step: 3, the config edit.** A TOML or quoting mistake breaks every verify, not just this step. The edit is one plain line with no shell quoting, and `sdlc verify` runs straight after it. As 0008 found, any `[verify] steps` change voids recorded passes: that's expected.
- **The step can make verify fail on main for an unrelated reason.** If `test/liquid-sync-init.sh` is flaky (its timeout case asserts 3–10 s), verify now fails where it passed before. It has passed every run so far. If it flakes, fix the test in its own item. Don't loosen it here.
- **A hung test stalls verify.** Accepted in the spec. The `/dev/null` stdin and the name printed before each run limit it.
- **bash 3.2 traps:** an empty array under `set -u`, and `set -e` inside a loop. Both are avoided by design (step 2), and the empty and fail cases in step 1 exercise them.
- **Recursion:** `test/run-tests.sh` runs the runner on its temp dirs only, never on `test/`, so the runner running it can't loop.
- **Rejected:**
  - an inline loop in `config.toml` (decided in spec);
  - stop-at-first-failure (decided in spec);
  - a per-test timeout, since macOS has no `timeout` without coreutils;
  - discovering tests with `find`, which would reach `test/fixtures/` and subdirectories;
  - moving `scripts/test-check-quadlets` (out of scope).
- **History:** 0008 added the only earlier verify step (`quadlets`) and deferred a `test/` harness to a later decision, which is this item. 0012 added `test/liquid-sync-init.sh`. CLAUDE.md's Testing section dates from 0002. `sdlc dep 0018 --check` reports no overlaps.

## Proof
- AC1: `test/run-tests.sh` prints `ok` for every case (pass, fail, not executable, subdirectory, stdin, empty, cwd) and exits 0.
- AC2: `sdlc verify` and `sdlc verify --fast`. Each shows `── tests: scripts/run-tests`, `── test/liquid-sync-init.sh`, `── test/run-tests.sh`, `run-tests: 2 passed, 0 failed`, and `verify: PASS`.
- AC3: step 4's `/tmp/0018-ac3.txt`. It has `FAIL test/zz-fail.sh (exit 1)`, `✗ tests failed`, and no `verify: PASS`. It's pasted in the PR.
- AC4: `grep -n 'scripts/run-tests' CLAUDE.md` finds the new bullet under `## Testing`.
- AC5: `git diff main -- .sdlc/config.toml` shows one added line and nothing removed.
- AC6: the `shellcheck` verify step passes with both new files included. `shellcheck -x scripts/run-tests test/run-tests.sh` is also clean on its own.
- **Rollback:** if the step misbehaves after merge, revert step 3's commit (`git revert <sha>`, through a PR). That turns the step off and leaves the runner and tests inert. Reverting the whole merge also removes the runner and the CLAUDE.md bullet. Either way, the next `sdlc verify` records a fresh pass.
- Final: `sdlc verify` ends with `verify: PASS`.
