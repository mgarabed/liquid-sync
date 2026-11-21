#!/usr/bin/env bash
# Tests for scripts/leak-check and the git hooks (work item 0001).
#
# Every fake leak is assembled at runtime from fragments, so nothing in this
# file matches the rules it tests (0001 spec, fourth area of concern). Each test
# runs in its own throwaway git repo under ${TMPDIR:-/tmp}, with the user's git
# config and personal pattern file kept out.
#
# Usage: test/leak-check.sh [test name...]
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
LC="$repo/scripts/leak-check"

unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_PREFIX \
  GIT_ALTERNATE_OBJECT_DIRECTORIES XDG_CONFIG_HOME
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=Test GIT_COMMITTER_NAME=Test
export GIT_AUTHOR_EMAIL=1+test@users.noreply.github.com
export GIT_COMMITTER_EMAIL=$GIT_AUTHOR_EMAIL

tmp_root=$(mktemp -d "${TMPDIR:-/tmp}/leak-check-test.XXXXXX")
trap 'rm -rf "$tmp_root"' EXIT
export HOME="$tmp_root/home"
mkdir -p "$HOME"
# Default: no personal pattern file. Tests that need one point here at a temp file.
export LIQUID_SYNC_LEAK_PATTERNS="$tmp_root/no-personal-patterns"

# --- fake values, built from fragments ---------------------------------------
ip() { local IFS=.; printf '%s' "$*"; }
at='@'
tsk=$(printf 'ts%s' key)
fake_key="$tsk-auth-kAbCdEf123456-XyZ7890"
ts_net=$(printf 'ts.%s' net)
fake_host="laptop.tail-example.$ts_net"
setup_scheme=$(printf 'obsidian://setup%s' livesync)
fake_uri="$setup_scheme?settings=%5B%22aGVsbG8%22%5D"
fake_url="https://admin:hunter2${at}couch.example.org/db"
pw_name=$(printf 'COUCHDB_PASS%s' WORD)
fake_email="someone.private${at}example.org"

# --- helpers -----------------------------------------------------------------
fail() {
  printf '  %s\n' "$@" >&2
  exit 1
}

new_repo() { # <name>: make and enter an empty repo
  local dir="$tmp_root/$1"
  mkdir -p "$dir"
  cd "$dir"
  git init -q -b main
}

hook_repo() { # <name>: a repo with this checkout's scripts and hooks installed
  new_repo "$1"
  cp -R "$repo/scripts" "$repo/.githooks" .
  scripts/install-hooks >/dev/null
}

# run <cmd...>: sets $out (stdout+stderr) and $rc without tripping set -e.
run() {
  rc=0
  out=$("$@" 2>&1) || rc=$?
}

expect_rc() { # <want>
  [ "$rc" -eq "$1" ] || fail "expected exit $1, got $rc" "output:" "$out"
}

expect_has() { # <text>
  case "$out" in *"$1"*) ;; *) fail "expected output to contain: $1" "output:" "$out" ;; esac
}

expect_lacks() { # <text>
  case "$out" in *"$1"*) fail "output must not contain a leaked value" "output:" "$out" ;; esac
}

tree_check() { # <content> <rule> <yes|no>: does the tree scan flag <content> with <rule>?
  printf '%s\n' "$1" > f.txt
  git add f.txt
  run "$LC" --tree
  if [ "$3" = yes ]; then
    expect_rc 1
    expect_has "f.txt:1: $2"
  else
    case "$out" in *"f.txt:1: $2"*) fail "rule $2 should not match: $1" "output:" "$out" ;; esac
  fi
}

# --- tests -------------------------------------------------------------------

# 0001 AC8: one positive and one negative case per required generic rule.
t_generic_rules_cover_required() {
  new_repo generic
  tree_check "host $(ip 10 1 2 3) up" private-ipv4 yes
  tree_check "$(ip 172 20 0 5)" private-ipv4 yes
  tree_check "url http://$(ip 192 168 1 10):5984/" private-ipv4 yes
  tree_check "tailscale $(ip 100 101 102 103)" private-ipv4 yes
  tree_check "loopback $(ip 127 0 0 1)" private-ipv4 no
  tree_check "public $(ip 172 32 0 1) and $(ip 100 128 0 1)" private-ipv4 no
  tree_check "version 1.$(ip 10 2 3 4)" private-ipv4 no
  tree_check "https://$fake_host/" tailnet-hostname yes
  tree_check "clients use a *.$ts_net name" tailnet-hostname no
  tree_check "key=$fake_key" tailscale-key yes
  tree_check "generate a $tsk- auth key" tailscale-key no
  tree_check "$fake_uri" livesync-setup-uri yes
  tree_check "$setup_scheme is the scheme" livesync-setup-uri no
  tree_check "$fake_url" url-credentials yes
  tree_check "https://user:<password>${at}host and https://couch.example.org/db" url-credentials no
  tree_check "$pw_name=s3cr3t-value" secret-assignment yes
  tree_check "  $pw_name: \"s3cr3t\"" secret-assignment yes
  tree_check "$pw_name=" secret-assignment no
  tree_check "$pw_name=\"\$1\"" secret-assignment no
  # 0001 R4: generic matches show at most 4 characters of the value.
  tree_check "$fake_key" tailscale-key yes
  expect_lacks "$fake_key"
  expect_lacks "${fake_key:0:5}"
}

# 0001 AC6: the marker allows its own line only.
t_allow_marker_line_only() {
  new_repo marker
  printf '%s\n' "a $(ip 10 0 0 7) # leak-check: allow" "b $(ip 10 0 0 8)" > f.txt
  git add f.txt
  run "$LC" --tree
  expect_rc 1
  expect_has "f.txt:2: private-ipv4"
  case "$out" in *"f.txt:1:"*) fail "marked line was reported" "$out" ;; esac
  # Staged variant: the same rule applies to added lines.
  hook_repo marker-staged
  printf '%s\n' "a $(ip 10 0 0 7) # leak-check: allow" "b $(ip 10 0 0 8)" > f.txt
  git add f.txt
  run scripts/leak-check --staged
  expect_rc 1
  expect_has "f.txt:2: private-ipv4"
  case "$out" in *"f.txt:1:"*) fail "marked staged line was reported" "$out" ;; esac
}

# 0001 AC6: an allowlist entry needs both its path glob and its rule to match.
t_allowlist_file_and_rule_only() {
  new_repo allowlist
  mkdir docs
  printf '%s\t%s\n' 'docs/*.md' private-ipv4 > .leak-allow
  printf '%s\n' "$(ip 10 0 0 7)" "$fake_key" > docs/x.md
  printf '%s\n' "$(ip 10 0 0 8)" > y.md
  git add .leak-allow docs/x.md y.md
  run "$LC" --tree
  expect_rc 1
  expect_has "docs/x.md:2: tailscale-key"
  expect_has "y.md:1: private-ipv4"
  case "$out" in *"docs/x.md:1:"*) fail "allowlisted match was reported" "$out" ;; esac
}

# 0001 AC7: a missing personal file warns once, naming the path, and passes.
t_missing_personal_warns() {
  new_repo missing
  local path="$tmp_root/nowhere/leak-patterns"
  printf 'nothing to see\n' > f.txt
  git add f.txt
  LIQUID_SYNC_LEAK_PATTERNS=$path run "$LC" --tree
  expect_rc 0
  local n
  n=$(printf '%s\n' "$out" | grep -cF "$path")
  [ "$n" -eq 1 ] || fail "expected one warning naming $path, got $n" "$out"
  # Without the env var, the XDG default is named instead.
  XDG_CONFIG_HOME="$tmp_root/xdg" LIQUID_SYNC_LEAK_PATTERNS='' run "$LC" --tree
  expect_rc 0
  expect_has "$tmp_root/xdg/liquid-sync/leak-patterns"
}

# 0001 AC7: a group- or world-readable personal file gets a chmod 600 warning.
t_personal_file_perms_warn() {
  new_repo perms
  local pf="$tmp_root/perms-patterns"
  printf '# none\n' > "$pf"
  printf 'nothing to see\n' > f.txt
  git add f.txt
  chmod 644 "$pf"
  LIQUID_SYNC_LEAK_PATTERNS=$pf run "$LC" --tree
  expect_rc 0
  expect_has "chmod 600"
  chmod 600 "$pf"
  LIQUID_SYNC_LEAK_PATTERNS=$pf run "$LC" --tree
  expect_rc 0
  case "$out" in *"chmod 600"*) fail "warned about a chmod 600 file" "$out" ;; esac
}

# 0001 R4: personal matches show neither the value nor the pattern.
t_tree_personal_masked() {
  new_repo personal
  local pf="$tmp_root/personal-patterns"
  local pattern
  pattern=$(printf '%s' "$fake_email" | sed 's/[.]/\\./g')
  printf '%s\n' '# my patterns' "$pattern" > "$pf"
  chmod 600 "$pf"
  printf '%s\n' "contact: $(printf '%s' "$fake_email" | tr '[:lower:]' '[:upper:]')" > f.txt
  git add f.txt
  LIQUID_SYNC_LEAK_PATTERNS=$pf run "$LC" --tree
  expect_rc 1
  expect_has "f.txt:1: personal:2"
  expect_lacks "$fake_email"
  expect_lacks "$pattern"
  expect_lacks "SOMEONE"
  # An invalid personal pattern fails closed without echoing it.
  printf '%s\n' 'secretname(' > "$pf"
  LIQUID_SYNC_LEAK_PATTERNS=$pf run "$LC" --tree
  expect_rc 2
  expect_has "line 1: invalid regex"
  expect_lacks "secretname"
}

# 0001 AC1: a staged key blocks the commit, reported by file, line and rule, masked.
t_staged_generic_blocks() {
  hook_repo staged
  printf '%s\n' one two three > f.txt
  git add f.txt
  git commit -q -m "add f" >/dev/null 2>&1
  printf '%s\n' one two "key $fake_key" three > f.txt
  git add f.txt
  run scripts/leak-check --staged
  expect_rc 1
  expect_has "f.txt:3: tailscale-key"
  expect_lacks "$fake_key"
  run git commit -m "add key"
  [ "$rc" -ne 0 ] || fail "commit with a leak succeeded" "$out"
  expect_has "f.txt:3: tailscale-key"
  [ "$(git rev-list --count HEAD)" -eq 1 ] || fail "a commit was created"
  # Only added lines count: removing the line again is clean.
  git reset -q f.txt
  printf '%s\n' one two three > f.txt
  git add f.txt
  run scripts/leak-check --staged
  expect_rc 0
}

# 0001 AC2: a personal match blocks the commit and shows neither value nor pattern.
t_staged_personal_blocks_masked() {
  hook_repo staged-personal
  local pf="$tmp_root/staged-patterns" pattern
  pattern=$(printf '%s' "$fake_email" | sed 's/[.]/\\./g')
  printf '%s\n' "$pattern" > "$pf"
  chmod 600 "$pf"
  printf '%s\n' "mail $fake_email" > f.txt
  git add f.txt
  LIQUID_SYNC_LEAK_PATTERNS=$pf run scripts/leak-check --staged
  expect_rc 1
  expect_has "f.txt:1: personal:1"
  expect_lacks "$fake_email"
  expect_lacks "$pattern"
  LIQUID_SYNC_LEAK_PATTERNS=$pf run git commit -m "add mail"
  [ "$rc" -ne 0 ] || fail "commit with a personal leak succeeded" "$out"
  expect_lacks "$fake_email"
}

# 0001 AC11: install-hooks is idempotent.
t_install_hooks_idempotent() {
  new_repo install
  cp -R "$repo/scripts" .
  run scripts/install-hooks --dry-run
  expect_rc 0
  [ -z "$(git config core.hooksPath || true)" ] || fail "--dry-run changed config"
  run scripts/install-hooks
  expect_rc 0
  local before
  before=$(cat .git/config)
  run scripts/install-hooks
  expect_rc 0
  expect_has "nothing to do"
  [ "$(git config core.hooksPath)" = ".githooks" ] || fail "core.hooksPath not set"
  [ "$(cat .git/config)" = "$before" ] || fail "second run changed .git/config"
}

# 0001 AC10: pre-commit runs shellcheck on staged shell scripts, and fails
# (doesn't skip) when shellcheck is missing.
t_precommit_shellcheck_blocks() {
  hook_repo shellcheck
  local d='$'
  printf '%s\n' '#!/usr/bin/env bash' "echo ${d}1" > bad.sh
  git add bad.sh
  run git commit -m "bad script"
  [ "$rc" -ne 0 ] || fail "commit with a shellcheck finding succeeded" "$out"
  expect_has "SC2086"
  expect_has "bad.sh"
  # A shebang without a .sh name counts as a script too.
  git rm -q --cached bad.sh
  printf '%s\n' '#!/bin/sh' "echo ${d}1" > tool
  git add tool
  run git commit -m "bad tool"
  [ "$rc" -ne 0 ] || fail "commit of an extensionless bad script succeeded" "$out"
  expect_has "SC2086"
  # The staged version is checked, not the working copy.
  printf '%s\n' '#!/bin/sh' "echo \"${d}1\"" > tool
  run git commit -m "still bad in the index"
  [ "$rc" -ne 0 ] || fail "the working copy was checked instead of the index" "$out"
  git add tool
  run git commit -m "good tool"
  expect_rc 0
  # Without shellcheck on PATH, a staged script blocks the commit.
  local bin="$tmp_root/minimal-bin" tool_name
  mkdir -p "$bin"
  for tool_name in git bash sh env grep sed awk head tr cut dirname mktemp rm cat stat; do
    ln -sf "$(command -v "$tool_name")" "$bin/$tool_name"
  done
  printf '%s\n' '#!/usr/bin/env bash' 'echo ok' > good.sh
  git add good.sh
  PATH=$bin run git commit -m "no shellcheck"
  [ "$rc" -ne 0 ] || fail "commit succeeded without shellcheck" "$out"
  expect_has "shellcheck is not installed"
  # A commit with no shell scripts doesn't need shellcheck.
  git rm -q --cached good.sh
  printf 'notes\n' > notes.txt
  git add notes.txt
  PATH=$bin run git commit -m "notes only"
  expect_rc 0
}

# 0001 design: a malformed rules file fails with its own path and line.
t_malformed_rule_fails() {
  new_repo malformed
  mkdir scripts
  cp "$LC" scripts/leak-check
  printf '# comment\nno-tab-here\n' > scripts/leak-check.rules
  printf 'x\n' > f.txt
  git add f.txt
  run scripts/leak-check --tree
  expect_rc 2
  expect_has "leak-check.rules:2: malformed rule"
}

# --- runner ------------------------------------------------------------------
all_tests="generic_rules_cover_required allow_marker_line_only allowlist_file_and_rule_only
missing_personal_warns personal_file_perms_warn tree_personal_masked malformed_rule_fails
staged_generic_blocks staged_personal_blocks_masked install_hooks_idempotent
precommit_shellcheck_blocks"

selected=${*:-$all_tests}
failed=0
for name in $selected; do
  # Not `( ... ) || rc=$?`: that would switch off set -e inside the test.
  set +e
  ("t_$name")
  rc=$?
  set -e
  if [ "$rc" -eq 0 ]; then
    printf 'ok %s\n' "$name"
  else
    printf 'FAIL %s\n' "$name"
    failed=$((failed + 1))
  fi
done
if [ "$failed" -gt 0 ]; then
  printf '%d test(s) failed\n' "$failed"
  exit 1
fi
printf 'all leak-check tests passed\n'
