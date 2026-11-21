---
id: 0001
title: Block personal and secret leaks before commit and push
stage: plan
from: spec.md
---
# Plan: Block personal and secret leaks before commit and push

## Files that change
- `scripts/leak-check` (new): the scanner (bash). Modes `--tree`, `--staged` and `--push <remote>`; loads rules, allowlist and personal patterns; masks output.
- `scripts/leak-check.rules` (new): generic rules, `<name><TAB><ERE>` per line (spec R7).
- `scripts/leak-check.emails` (new): allowed author/committer email EREs (GitHub noreply only).
- `.leak-allow` (new): the allowlist (`<path glob><TAB><rule>`). Header comment only, no entries.
- `scripts/install-hooks` (new): sets `core.hooksPath` to `.githooks` (R9).
- `.githooks/pre-commit` (new): `scripts/leak-check --staged`, then shellcheck on staged shell scripts (R1, R8).
- `.githooks/pre-push` (new): `scripts/leak-check --push "$1"`, with the hook's stdin passed through (R2).
- `test/leak-check.sh` (new): the test runner, with one function per spec AC test name. It builds fakes at runtime and uses temporary repos under `${TMPDIR:-/tmp}`.
- `.sdlc/config.toml` (edit): adds verify steps `leak-check` and `leak-check-tests` after `shellcheck`.
- `README.md` (edit): a "Development" section covering `scripts/install-hooks`, the personal-pattern file path and format (`chmod 600`), and the `leak-check: allow` marker. No example personal values.

## Order of work
- [x] 1. Tree mode. Write `scripts/leak-check.rules`, `scripts/leak-check.emails` and `.leak-allow`, plus `scripts/leak-check` with shared plumbing:
  - rule loading, with a malformed-line error naming the rules file and line
  - personal-file lookup (R6: env var, then XDG path, then the missing-file warning, then the permission warning)
  - allow-marker and `.leak-allow` filtering (R5)
  - masking (R4)
  - `--tree` via `git grep -nIE`, with the hooks-not-enabled warning when `git config core.hooksPath` isn't `.githooks`
  - (as built) `--tree` dumps tracked text lines once with `git grep -z -n -I -e ''`, then every mode matches through the same `grep -noE` pass over a content file plus a parallel index file. That keeps one regex engine for matching and masking. Personal patterns match case-insensitively (`grep -i`).
  - (as built) `.leak-allow` has one entry: this item's `spec.md` for `private-ipv4`, because AC8's text names the CGNAT test address. AC9 only rules out entries under `scripts/`, `test/` and `.githooks/`.

  Write `test/leak-check.sh` with the harness and these tests: `generic_rules_cover_required`, `allow_marker_line_only`, `allowlist_file_and_rule_only` (tree variants), `missing_personal_warns` and `personal_file_perms_warn`, plus a tree-mode personal-masking check (`tree_personal_masked`) and `malformed_rule_fails`. Add verify steps `{ name = "leak-check", run = "scripts/leak-check --tree" }` and `{ name = "leak-check-tests", run = "test/leak-check.sh" }`. Confirm `scripts/leak-check --tree` is clean on this repo (AC9), then run `sdlc verify`.
- [x] 2. Staged mode and hook install. Add `--staged` to `scripts/leak-check`: parse `git diff --cached -U0 --no-color --no-ext-diff`, track the path from `+++ b/` and the line number from `@@ … +N`, and scan only `+` lines. Add `.githooks/pre-commit` (leak part only) and `scripts/install-hooks`. Tests: `staged_generic_blocks`, `staged_personal_blocks_masked`, the staged variant of `allow_marker_line_only`, and `install_hooks_idempotent` (AC11). Run `sdlc verify`.
- [x] 3. Pre-commit shellcheck. Extend `.githooks/pre-commit`:
  - find staged added or modified files (`git diff --cached --name-only --diff-filter=AM -z`) whose name ends in `.sh` or whose staged first line (`git show :<path> | head -1`) is a sh/bash shebang
  - run `git show :<path> | shellcheck -s bash -`. As built, `-s bash` is passed only when the staged file has no shebang, so a `#!/bin/sh` script is checked as sh.
  - (as built) a commit that stages no shell scripts doesn't need shellcheck installed
  - fail with "shellcheck is not installed" when `command -v shellcheck` fails

  Test: `precommit_shellcheck_blocks`, covering both the SC2086 case and the shellcheck-missing case. The missing case runs the hook with `PATH` set to a temporary directory that has symlinks to `git`, `bash`, `grep`, `sed`, `awk`, `head`, `tr` and `env`, but no shellcheck. Run `sdlc verify`.
- [x] 4. Push mode. Add `--push <remote>` to `scripts/leak-check`:
  - read the hook's stdin lines and skip deleted refs (all-zero local sha)
  - for each ref, the commits are `git rev-list <local sha> --not --remotes=<remote>`
  - per commit: check `%ae` and `%ce` against `scripts/leak-check.emails`, scan the message (`%B`), and scan added lines from `git show --format= -U0 --no-color --no-ext-diff <sha>` with the same diff parser as step 2
  - report each match as `<short sha> <file>:<line>`, or `<short sha> message` / `<short sha> author-email`. As built, message matches carry the message line (`<sha> message:<n>: <rule>`), and email findings never print the email.

  Add `.githooks/pre-push`. Tests use a temporary bare remote: `push_blocks_bad_author`, `push_blocks_message_leak` and `push_new_branch_scans_only_new_commits`. Run `sdlc verify`.
- [x] 5. Docs and the Linux check:
  - Add the README "Development" section.
  - Run `scripts/install-hooks` in this clone. That's local git config, not a repo change; confirm the verify warning goes away.
  - Run AC12 on Linux: `docker run --rm -v "$PWD":/src -w /src fedora:41 bash -c 'dnf -yq install git ShellCheck && test/leak-check.sh'`. That's Docker; Podman isn't installed on the dev machine. Record the result in the build report, or "unchecked" if the container can't run.
  - (as built) a worktree's `.git` file points at a host path, so the run mounts the main checkout at its own host path and adds `safe.directory '*'` in the container: `docker run --rm -v <main checkout>:<main checkout> -w <worktree> fedora:41 bash -c 'dnf -yq install git ShellCheck && git config --global --add safe.directory "*" && test/leak-check.sh && scripts/leak-check --tree'`. Result: all 14 tests pass on Fedora 41 (GNU bash 5.2, git 2.52), and `--tree` is clean.
  - Run `sdlc verify`.

## Risks
- **The riskiest step is 4 (push-range logic).** A wrong range either rescans history every push (slow, and it could block on the already-pushed initial history) or skips commits. Mitigated by `rev-list --not --remotes=<remote>` and AC5's test. The first real push after merge also exercises it against the existing pushed history: every pushed commit now has the noreply email, so the email check should pass.
- **Bash 3.2 on macOS:** no associative arrays, `mapfile`, `${x,,}` or `declare -n`. Rules go in parallel indexed arrays. The Linux run in step 5 catches GNU-vs-BSD differences in `grep`, `sed` and `stat`. File permissions in R6 need `stat -f %Lp` on BSD and `stat -c %a` on GNU, so the code tries both. `ls -l` parsing was rejected.
- **A rule matching its own text:** the rules file is scanned by `--tree`. Each ERE must be written so its literal text doesn't match it, for example by requiring a character class next to a literal that the regex text itself doesn't contain. AC9 fails loudly if one does, and the fix is to rework that rule, not to allowlist it (spec concern 4).
- **False positives on current or future docs:** private-IP and `*.ts.net` rules could hit planning docs that say `*.ts.net` or show example subnets. Today's tree is clean (checked during spec), and the documented answer is the `leak-check: allow` marker.
- **The pre-commit hook blocks sdlc's own commits** (intent/spec/plan, verify) if work-item text contains a pattern. That's intended: work items are public too.
- **The `--no-verify` bypass is uncovered by design** (spec concern 2, decided to skip). A `git push --no-verify` that never goes through `sdlc submit` gets past every layer.
- **The existing verify `shellcheck` step** finds scripts by a `#!…sh` line *anywhere* in a file, not only the first line. A Markdown file with a shebang inside a code block would be handed to shellcheck and fail. No current file triggers this, and tightening it is out of this item's scope. If it bites during the build, capture a follow-up rather than widening this item.
- **Considered and rejected:**
  - gitleaks: decided in intent, it would need a binary and an ADR.
  - Scanning full history in verify: decided in intent as too slow as the repo grows.
  - A single regex pass with all rules joined: it loses the rule name per match, which R1 needs.
  - Storing literal fakes in `test/fixtures/` with allowlist entries: decided in spec, it breaks AC9.
- **Overlaps:** `sdlc dep 0001 --check` found none. The other open items (0002–0007) are unplanned.

## Proof
- AC1: `test/leak-check.sh` → `ok staged_generic_blocks`
- AC2: `test/leak-check.sh` → `ok staged_personal_blocks_masked`
- AC3: `test/leak-check.sh` → `ok push_blocks_bad_author`
- AC4: `test/leak-check.sh` → `ok push_blocks_message_leak`
- AC5: `test/leak-check.sh` → `ok push_new_branch_scans_only_new_commits`
- AC6: `test/leak-check.sh` → `ok allow_marker_line_only`, `ok allowlist_file_and_rule_only`
- AC7: `test/leak-check.sh` → `ok missing_personal_warns`, `ok personal_file_perms_warn`
- AC8: `test/leak-check.sh` → `ok generic_rules_cover_required`
- AC9: `scripts/leak-check --tree; echo $?` → `0`, and `grep -vE '^(#|$)' .leak-allow | grep -cE '^(scripts|test|\.githooks)/'` → `0`
- AC10: `test/leak-check.sh` → `ok precommit_shellcheck_blocks`
- AC11: `test/leak-check.sh` → `ok install_hooks_idempotent`. In this clone, `scripts/install-hooks && scripts/install-hooks; git config core.hooksPath` → `.githooks`
- AC12: the step 5 `docker run … fedora:41 … test/leak-check.sh` exits 0, or the build report says "unchecked: <reason>"
- AC13: `sdlc verify` → `verify: PASS` with the steps `shellcheck`, `leak-check` and `leak-check-tests`
- **Rollback** (high tier). If the hooks misbehave after merge:
  - `git config --unset core.hooksPath` disables them in that clone immediately.
  - To remove the feature, `git revert -m 1 <merge sha>` drops the verify steps and scripts. Nothing outside the repo's own files is written, apart from the local `core.hooksPath` setting and the user-managed personal-pattern file, which the check only reads.

## Parallel tracks
<!-- None: every step edits scripts/leak-check and test/leak-check.sh. -->
