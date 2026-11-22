---
id: 0001
title: Block personal and secret leaks before commit and push
stage: spec
from: intent.md
---
# Spec: Block personal and secret leaks before commit and push

## Areas of concern
- [x] Missing personal-pattern file fails open — security-baseline #8 says "fail closed", but the intent chose warn-and-continue so CI and other clones (which can never have the file) still work — keep warn-and-continue as decided in the intent; the warning names the expected path so a misconfigured machine is obvious, and the personal patterns are re-checked on every push from a machine that has the file. — decided: keep warn-and-continue.
- [x] Agents can bypass hooks with `git commit --no-verify` / `-n` or `git push --no-verify` — the hooks are the main layer for content that never reaches `sdlc verify` (commit messages, author emails) — add `ask` rules for those commands to the project `.claude/settings.json` (control-plane, already covered by this item's `high` tier). Best effort only: prefix rules miss reordered flags, so `sdlc verify` and the pre-push re-scan stay the backstop. — decided: skip; no permission rules. The `sdlc verify` tree scan and the pre-push re-scan are the backstop (R12 and AC14 removed).
- [x] Hooks aren't active in a fresh clone — git can't enable committed hooks by itself (`core.hooksPath` is local config), which fights the "no pets" principle — ship an idempotent `scripts/install-hooks`, and have the verify step print a warning (not fail, so CI still passes) when `core.hooksPath` isn't `.githooks`. `./liquid-sync init` calls `scripts/install-hooks` once the CLI exists (Phase 2). — decided: warn in verify, don't fail.
- [x] The tests need example leaks, and the pattern file looks like leaks — security-baseline #1 forbids secrets in fixtures, the sdlc secrets guard blocks writing realistic key formats, and the tree scan would flag its own files — tests build every fake value at runtime from fragments (nothing leak-shaped is stored in the repo), and the generic patterns are written so they don't match their own text. AC9 proves the repo's own tree scans clean with no allowlist entries for the check's files. — decided: runtime-built fakes.

## Requirements
- R1: A commit fails when an added line in the staged diff matches a generic or personal leak rule. The output names the file, line number and rule name for each match, and exits non-zero.
- R2: A push fails when any commit that the remote doesn't have yet adds a matching line, has a matching commit message, or has an author or committer email that isn't on the allowed-email list.
- R3: The tree scan (run by `sdlc verify`) fails when any tracked text file has a matching line.
- R4: Output never contains a full matched value. Generic matches show at most the first 4 characters; personal matches show none, and never show the personal pattern itself (they're reported as `personal:<line number in the pattern file>`).
- R5: A match is allowed only when its line carries the marker `leak-check: allow`, or when the file and rule appear together in the root allowlist file `.leak-allow`. A marker or allowlist entry can't silence a rule on other lines or other files.
- R6: Personal patterns load from `$LIQUID_SYNC_LEAK_PATTERNS` when set, otherwise `${XDG_CONFIG_HOME:-$HOME/.config}/liquid-sync/leak-patterns`. When the file is missing, every mode prints one warning naming the path it looked for and continues with the generic rules only. When the file is readable by group or others, the check prints a warning recommending `chmod 600`.
- R7: The generic rules detect at least: private IPv4 addresses (10/8, 172.16/12, 192.168/16, 100.64/10 Tailscale CGNAT), but not loopback; `*.ts.net` hostnames; Tailscale `tskey-` auth keys; LiveSync setup URIs; URLs with embedded `user:password@` credentials; and non-empty values assigned to variables whose names contain PASSWORD, PASSPHRASE, SECRET, TOKEN or AUTHKEY.
- R8: The pre-commit hook also runs shellcheck on the staged content of every staged shell script (detected by `.sh` extension or a sh/bash shebang) and fails on any finding. If shellcheck isn't installed, it fails with a message saying so (it doesn't skip).
- R9: `scripts/install-hooks` sets `core.hooksPath` to `.githooks`. Running it twice changes nothing and exits 0.
- R10: The check runs unchanged on macOS (BSD grep/sed, bash 3.2) and Linux (GNU userland), using only bash, git, grep, sed and awk.
- R11: Every committed script uses `set -euo pipefail` and passes shellcheck.

## Design
**Files (all new except where noted):**
- `scripts/leak-check`: bash. Modes:
  - `--staged`: scans `git diff --cached -U0 --no-color` added lines, tracking `+++ b/<path>` and `@@ … +<n>` hunk headers to report real line numbers.
  - `--push <remote>`: reads pre-push stdin (`<local ref> <local sha> <remote ref> <remote sha>`). For each pushed ref, the commit range is `git rev-list <local sha> --not --remotes=<remote>`, so new branches only scan commits the remote doesn't have. Per commit it checks author and committer email (`git log -1 --format=%ae%n%ce`), the message, and `git show --format= -U0` added lines. Deleted refs (`0000…` local sha) are skipped.
  - `--tree`: scans `git ls-files` through `git grep -nIE` (which skips binary files), one pass per rule.
  - Matching uses `grep -E` (POSIX ERE, no `-P`) on the scan input; rule names and line numbers are tracked in awk, not in matched text.
- `scripts/leak-check.rules`: generic rules, one per line, `<name><TAB><ERE>`; `#` comments allowed.
- `scripts/leak-check.emails`: allowed author/committer emails as anchored EREs. Initial entries: `^[0-9]+\+[^@]+@users\.noreply\.github\.com$` and `^noreply@github\.com$` (GitHub's web-UI committer).
- `.leak-allow`: allowlist, `<path glob><TAB><rule name>` per line. Starts empty, apart from a header comment.
- `.githooks/pre-commit`: runs `scripts/leak-check --staged`, then shellcheck on staged shell scripts via `git show :<path> | shellcheck -`.
- `.githooks/pre-push`: runs `scripts/leak-check --push "$1"` with stdin passed through.
- `scripts/install-hooks`: `git config core.hooksPath .githooks`.
- `test/leak-check.sh`: a self-contained test runner. Each test makes a temporary git repo under `${TMPDIR:-/tmp}` and builds fake values at runtime (e.g. `p1=tskey; p2=auth; …`) so no leak-shaped literal is committed. It sets `LIQUID_SYNC_LEAK_PATTERNS` to a temporary file, never the real one. Each test prints `ok <name>` or `FAIL <name>`, and the runner exits non-zero on any failure.
- `.sdlc/config.toml` (changed): adds verify steps `leak-check` (`scripts/leak-check --tree`) and `leak-check-tests` (`test/leak-check.sh`). The `--tree` mode also prints the hooks-not-enabled warning.
- `README.md` (changed): a short "Development" section covering `scripts/install-hooks`, the personal-pattern file location and format (one ERE per line, `chmod 600`), and the allow marker. It contains no example personal values.

**Personal pattern file format:** one ERE per line, `#` comments. The file is never copied, echoed or logged.

**Error states:** a malformed rule line (no tab) fails the check with the file and line of the rule, not the scanned content. If git isn't available or the command is run outside a repo, it fails with a one-line message. Every failure exits non-zero, so a broken check blocks instead of passing silently.

**Rollback:** `git config --unset core.hooksPath` disables the hooks immediately. Reverting the merge commit removes the verify steps. No data is touched.

## Acceptance criteria
- AC1 (R1, R4): `test/leak-check.sh` test `staged_generic_blocks` stages a file with a runtime-built `tskey-` key. `--staged` exits 1, the output contains `<file>:<line>` and the rule name, and the output doesn't contain the full key.
- AC2 (R1, R4, R6): test `staged_personal_blocks_masked` makes a personal pattern file with a fake email and stages a line containing that email. `--staged` exits 1, the output has `personal:1`, and the output contains neither the email nor the pattern.
- AC3 (R2): test `push_blocks_bad_author` commits with a non-allowed author email in a repo with a bare remote. `git push` through the installed hook exits non-zero, and the remote ref is unchanged.
- AC4 (R2): test `push_blocks_message_leak` makes a commit whose message contains a runtime-built credentialed URL. The push is rejected.
- AC5 (R2): test `push_new_branch_scans_only_new_commits` pushes a new branch whose base contains an allowlisted leak, plus one clean new commit. The push succeeds.
- AC6 (R5): tests `allow_marker_line_only` and `allowlist_file_and_rule_only`. A marked line passes while an unmarked match in the same file fails, and an allowlist entry for rule A in file X doesn't allow rule B in X or rule A in Y.
- AC7 (R6): test `missing_personal_warns` sets `LIQUID_SYNC_LEAK_PATTERNS` to a missing path. A clean `--tree` exits 0 and its output contains one warning naming that path. Test `personal_file_perms_warn` makes a mode-644 file and checks for the `chmod 600` warning.
- AC8 (R7): test `generic_rules_cover_required` checks one runtime-built positive and one negative case per required rule, including `127.0.0.1` not matching and `100.101.102.103` matching.
- AC9 (R3, R5): `scripts/leak-check --tree` on this repo exits 0, and `.leak-allow` contains no entries for `scripts/`, `test/` or `.githooks/`.
- AC10 (R8): test `precommit_shellcheck_blocks` stages a script containing `echo $1`. The commit fails with SC2086. With `PATH` stripped of shellcheck, it fails with the not-installed message.
- AC11 (R9): running `scripts/install-hooks` twice exits 0 both times, and `git config core.hooksPath` prints `.githooks`.
- AC12 (R10): `test/leak-check.sh` passes on macOS (the dev machine). Linux is checked by running it in a `fedora` container (e.g. `podman run --rm -v "$PWD":/src:Z -w /src fedora:41 bash -c 'dnf -yq install git ShellCheck && test/leak-check.sh'`). If no container runtime is available, this is noted in the build report as unchecked.
- AC13 (R11): `sdlc verify` passes, including the shellcheck step over the new scripts.

## Open questions
- [x] Where does the personal pattern file live by default, and is it overridable by an env var? — answer: `${XDG_CONFIG_HOME:-$HOME/.config}/liquid-sync/leak-patterns`, overridable with `LIQUID_SYNC_LEAK_PATTERNS` (R6). The documented path reveals nothing personal.
- [x] How does the check exempt its own pattern and test files, which must contain example leaks? — answer: it doesn't exempt them. Tests build fakes at runtime, and the rules are written not to match their own text (fourth area of concern, AC9).
- [x] How are hooks enabled: by hand, or by `./liquid-sync init`? — answer: `scripts/install-hooks` now (R9), plus a verify warning when the hooks aren't enabled; `./liquid-sync init` will call it once the CLI exists (Phase 2, a separate item).
- [x] Should allowed author emails be configurable, or just the noreply pattern? — answer: configurable in the in-repo `scripts/leak-check.emails`, which starts with the GitHub noreply patterns only. Personal emails never go in that file.

## Standards applied
- sdlc:security-baseline: #1 (no secrets in fixtures, so fakes are built at runtime), #4 (personal data never in output, so personal matches are masked fully), #6 (no new dependencies), #7 (no new permissions; the proposed Claude permission rules were declined), #8 (fail-closed conflict escalated, and broken-check states block).
- CLAUDE.md: bash with `set -euo pipefail` and shellcheck, boring tech (no ADR needed), no pets (the install script and verify warning).
- No stack skill applies (stack `generic`), and there are no repo-local skills.
