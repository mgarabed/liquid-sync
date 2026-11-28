#!/usr/bin/env bash
# Tests for scripts/run-tests (0018 AC1). Each case builds its own directory of
# fake tests under a temp dir and runs the runner on it, never on test/, so the
# runner running this file can't recurse.
# Prints "ok <case>" or "FAIL <case>: why"; exits 1 on any failure.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp="$(mktemp -d /tmp/run-tests-test.XXXXXX)"

# Refuse to delete anything but our own temp dir.
assert_tmp() {
  case "$tmp" in
    /tmp/run-tests-test.?*) ;;
    *) echo "refusing to clean up unexpected path: $tmp" >&2; return 1 ;;
  esac
}
assert_tmp
trap 'assert_tmp && rm -rf "$tmp"' EXIT

failed=0
ok() { echo "ok $1"; }
fail() { echo "FAIL $1: $2"; failed=1; }

# Write an executable fake test: fake DIR NAME BODY...
fake() {
  local dir="$1" name="$2"
  shift 2
  mkdir -p "$(dirname "$dir/$name")"
  { echo '#!/usr/bin/env bash'; printf '%s\n' "$@"; } >"$dir/$name"
  chmod 0755 "$dir/$name"
}

# Run the runner on DIR. Sets rc; output lands in $tmp/out.
# STDIN_FILE, if set, is the runner's stdin (default /dev/null).
rc=0
run() {
  set +e
  "$here/scripts/run-tests" "$1" <"${STDIN_FILE:-/dev/null}" >"$tmp/out" 2>&1
  rc=$?
  set -e
}
has() { grep -qF -- "$1" "$tmp/out"; }

# pass: output shown, name printed before it runs, summary line.
d="$tmp/pass"
fake "$d" a.sh 'echo hello-a'
run "$d"
if [ "$rc" -eq 0 ] && has hello-a && has "── $d/a.sh" && has "1 passed, 0 failed"; then
  ok "pass"
else
  fail "pass" "rc=$rc"
fi

# fail: named with its exit code, and the run continues past it.
d="$tmp/fail"
fake "$d" a.sh 'echo marker-a'
fake "$d" b.sh 'exit 3'
fake "$d" c.sh 'echo marker-c'
run "$d"
if [ "$rc" -eq 1 ] && has "FAIL $d/b.sh (exit 3)" && has marker-a && has marker-c \
  && has "2 passed, 1 failed"; then
  ok "fail"
else
  fail "fail" "rc=$rc"
fi

# not executable: named, fails the run, and isn't run.
d="$tmp/noexec"
fake "$d" a.sh 'echo marker-noexec'
chmod 0644 "$d/a.sh"
run "$d"
if [ "$rc" -eq 1 ] && has "FAIL $d/a.sh: not executable" && ! has marker-noexec; then
  ok "not executable"
else
  fail "not executable" "rc=$rc"
fi

# subdirectory: never run.
d="$tmp/subdir"
fake "$d" a.sh 'echo marker-a'
fake "$d" sub/x.sh 'echo marker-sub' 'exit 1'
run "$d"
if [ "$rc" -eq 0 ] && has marker-a && ! has marker-sub; then
  ok "subdirectory"
else
  fail "subdirectory" "rc=$rc"
fi

# stdin: each test reads /dev/null, not the runner's own stdin.
d="$tmp/stdin"
fake "$d" a.sh 'cat' 'echo stdin-eof'
echo leak-marker >"$tmp/stdin-input"
STDIN_FILE="$tmp/stdin-input" run "$d"
if [ "$rc" -eq 0 ] && has stdin-eof && ! has leak-marker; then
  ok "stdin"
else
  fail "stdin" "rc=$rc"
fi

# empty: passes and says so.
d="$tmp/empty"
mkdir -p "$d"
run "$d"
if [ "$rc" -eq 0 ] && has "no tests"; then
  ok "empty"
else
  fail "empty" "rc=$rc"
fi

# cwd: tests run from the repo root, even when the runner starts elsewhere.
d="$tmp/cwd"
# shellcheck disable=SC2016 # expands in the fake test, not here
fake "$d" a.sh 'echo "cwd=$(pwd -P)"'
cd "$tmp"
run "$d"
cd "$here"
if [ "$rc" -eq 0 ] && has "cwd=$here"; then
  ok "cwd"
else
  fail "cwd" "got: $(grep '^cwd=' "$tmp/out" || true)"
fi

exit "$failed"
