#!/usr/bin/env bash
# Tests for `./liquid-sync init` (0012 AC1-AC5, AC7). Each case runs against a
# fresh copy of the scripts in a temp dir, with a fake couchdb.env.example and
# fake credentials only. A stub PODMAN logs its argv and starts nothing, and
# COUCHDB_URL points at a closed port, so nothing real is touched.
# Prints "ok <case>" or "FAIL <case>: why"; exits 1 on any failure.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
tmp="$(mktemp -d /tmp/liquid-sync-init-test.XXXXXX)"

# Refuse to delete anything but our own temp dir.
assert_tmp() {
  case "$tmp" in
    /tmp/liquid-sync-init-test.?*) ;;
    *) echo "refusing to clean up unexpected path: $tmp" >&2; return 1 ;;
  esac
}
assert_tmp
trap 'assert_tmp && rm -rf "$tmp"' EXIT

failed=0
ok() { echo "ok $1"; }
fail() { echo "FAIL $1: $2"; failed=1; }

file_mode() { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"; }
file_mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1"; }

# The stub podman: appends its argv to $STUB_LOG and succeeds.
mkdir -p "$tmp/bin"
cat >"$tmp/bin/podman-stub" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$STUB_LOG"
exit 0
EOF
chmod +x "$tmp/bin/podman-stub"

n=0
T=""
# Make a fresh copy of the scripts in $tmp/tN and point T at it.
new_tree() {
  n=$((n + 1))
  T="$tmp/t$n"
  mkdir -p "$T/lib" "$T/scripts" "$T/config"
  cp "$here/liquid-sync" "$T/"
  cp "$here/lib/common.sh" "$T/lib/"
  cp "$here/scripts/check-couchdb-config" "$T/scripts/"
  cp "$here"/config/*.ini "$T/config/"
  printf '%s\n' '# Fake example for tests.' 'COUCHDB_USER=admin' 'COUCHDB_PASSWORD=' \
    >"$T/couchdb.env.example"
}

# Run liquid-sync in $T. Sets rc; output lands in $T/out and $T/err.
# PATH_PREFIX, if set, goes in front of PATH (for a stub ln).
rc=0
run() {
  set +e
  env -u COUCHDB_USER -u COUCHDB_PASSWORD \
    PATH="${PATH_PREFIX:+$PATH_PREFIX:}$PATH" \
    PODMAN="$tmp/bin/podman-stub" STUB_LOG="$T/calls.log" \
    COUCHDB_URL=http://127.0.0.1:9 LIQUID_SYNC_TIMEOUT="${TIMEOUT:-0}" \
    "$T/liquid-sync" "$@" >"$T/out" 2>"$T/err"
  rc=$?
  set -e
}

password_in() { grep '^COUCHDB_PASSWORD=' "$1" | tail -n 1 | cut -d= -f2-; }
leaked() { grep -qF -- "$1" "$T/out" "$T/err" ${2:+"$2"}; }
temp_files() { find "$T" -maxdepth 1 -name '.couchdb.env.*' | wc -l | tr -d ' '; }

# 0012 AC1: dispatch, help and exit codes.
new_tree
run --help
if [ "$rc" -eq 0 ] && grep -q '^  init' "$T/out"; then ok "AC1 --help"; else fail "AC1 --help" "rc=$rc"; fi
run
if [ "$rc" -eq 0 ] && grep -q '^  init' "$T/out"; then ok "AC1 no arguments"; else fail "AC1 no arguments" "rc=$rc"; fi
run bogus
if [ "$rc" -eq 2 ] && grep -q '^  init' "$T/err" && [ ! -s "$T/out" ]; then
  ok "AC1 unknown command"
else
  fail "AC1 unknown command" "rc=$rc, want 2 with the list on stderr"
fi
run init --help
if [ "$rc" -eq 0 ] && grep -q 'liquid-sync init' "$T/out" && [ ! -e "$T/couchdb.env" ]; then
  ok "AC1 init --help"
else
  fail "AC1 init --help" "rc=$rc"
fi

# 0012 AC2: a missing env file is created at 0600 with the example's lines
# and a fresh 32-character password that never shows in output or argv.
new_tree
run init
pw=""
[ -e "$T/couchdb.env" ] && pw="$(password_in "$T/couchdb.env")"
if [ ! -e "$T/couchdb.env" ]; then
  fail "AC2 create" "no couchdb.env"
elif [ "$(file_mode "$T/couchdb.env")" != 600 ]; then
  fail "AC2 create" "mode $(file_mode "$T/couchdb.env")"
elif ! printf '%s\n' "$pw" | grep -Eq '^[A-Za-z0-9]{32}$'; then
  fail "AC2 create" "password isn't 32 characters of [A-Za-z0-9]"
elif ! diff <(grep -v '^COUCHDB_PASSWORD=' "$T/couchdb.env.example") \
            <(grep -v '^COUCHDB_PASSWORD=' "$T/couchdb.env") >/dev/null; then
  fail "AC2 create" "non-password lines differ from the example"
elif leaked "$pw" "$T/calls.log"; then
  fail "AC2 create" "password appears in output or podman argv"
elif [ "$rc" -ne 1 ] || ! grep -q 'couchdb.env created (mode 0600)' "$T/out"; then
  fail "AC2 create" "rc=$rc (want 1 at the wait step) or no 'created' line"
elif ! grep -q '^compose up -d$' "$T/calls.log"; then
  fail "AC2 create" "podman compose up -d wasn't called"
elif [ "$(temp_files)" != 0 ]; then
  fail "AC2 create" "temp file left behind"
else
  ok "AC2 create"
fi

# 0012 AC3: an existing env file is left alone; a loose mode only warns.
canary="canaryPw$$x"
for mode in 600 644; do
  new_tree
  printf '%s\n' 'COUCHDB_USER=admin' "COUCHDB_PASSWORD=$canary" >"$T/couchdb.env"
  chmod "$mode" "$T/couchdb.env"
  touch -t 202001010000 "$T/couchdb.env"
  sum_before="$(cksum <"$T/couchdb.env")"
  mtime_before="$(file_mtime "$T/couchdb.env")"
  run init
  if [ "$(cksum <"$T/couchdb.env")" != "$sum_before" ]; then
    fail "AC3 existing $mode" "content changed"
  elif [ "$(file_mtime "$T/couchdb.env")" != "$mtime_before" ]; then
    fail "AC3 existing $mode" "mtime changed"
  elif [ "$(file_mode "$T/couchdb.env")" != "$mode" ]; then
    fail "AC3 existing $mode" "mode changed to $(file_mode "$T/couchdb.env")"
  elif leaked "$canary" "$T/calls.log"; then
    fail "AC3 existing $mode" "canary appears in output or podman argv"
  elif ! grep -q 'couchdb.env exists, left as is' "$T/out"; then
    fail "AC3 existing $mode" "no 'exists' line"
  elif [ "$mode" = 644 ] && ! grep -q 'warning:.*mode 644' "$T/err"; then
    fail "AC3 existing $mode" "no mode warning"
  elif [ "$mode" = 600 ] && grep -q 'warning:' "$T/err"; then
    fail "AC3 existing $mode" "unexpected warning"
  else
    ok "AC3 existing $mode"
  fi
done

# 0012 AC4: two fresh runs give different passwords.
new_tree; run init; pw1="$(password_in "$T/couchdb.env")"
new_tree; run init; pw2="$(password_in "$T/couchdb.env")"
if [ -n "$pw1" ] && [ -n "$pw2" ] && [ "$pw1" != "$pw2" ]; then
  ok "AC4 fresh passwords"
else
  fail "AC4 fresh passwords" "passwords missing or equal"
fi

# 0012 AC4: if another writer creates couchdb.env first (a stub ln creates the
# target just before linking), init keeps that file and removes its temp file.
new_tree
mkdir -p "$T/stub-ln"
cat >"$T/stub-ln/ln" <<EOF
#!/bin/sh
printf '%s\n' 'COUCHDB_USER=admin' 'COUCHDB_PASSWORD=$canary' >"\$2"
exec /bin/ln "\$@"
EOF
chmod +x "$T/stub-ln/ln"
PATH_PREFIX="$T/stub-ln" run init
if [ "$(password_in "$T/couchdb.env")" != "$canary" ]; then
  fail "AC4 lost race" "the other writer's file was replaced"
elif [ "$(temp_files)" != 0 ]; then
  fail "AC4 lost race" "temp file left behind"
elif ! grep -q 'couchdb.env exists, left as is' "$T/out"; then
  fail "AC4 lost race" "no 'exists' line"
elif leaked "$canary"; then
  fail "AC4 lost race" "canary appears in output"
else
  ok "AC4 lost race"
fi

# 0012 AC5: --dry-run writes nothing and runs nothing.
new_tree
run init --dry-run
if [ "$rc" -ne 0 ]; then
  fail "AC5 dry run" "rc=$rc"
elif ! grep -q 'would create couchdb.env' "$T/out"; then
  fail "AC5 dry run" "no 'would create' line"
elif [ -e "$T/couchdb.env" ] || [ "$(temp_files)" != 0 ]; then
  fail "AC5 dry run" "a file was written"
elif [ -e "$T/calls.log" ]; then
  fail "AC5 dry run" "podman was called"
else
  ok "AC5 dry run"
fi

# 0012 AC7: with nothing listening, init gives up after the timeout with a
# message naming CouchDB and the URL, and no credentials.
new_tree
printf '%s\n' 'COUCHDB_USER=admin' "COUCHDB_PASSWORD=$canary" >"$T/couchdb.env"
chmod 600 "$T/couchdb.env"
start="$SECONDS"
TIMEOUT=3 run init
took=$((SECONDS - start))
if [ "$rc" -ne 1 ]; then
  fail "AC7 timeout" "rc=$rc"
elif [ "$took" -lt 3 ] || [ "$took" -ge 10 ]; then
  fail "AC7 timeout" "took ${took}s"
elif ! grep -q 'CouchDB.*http://127.0.0.1:9' "$T/err"; then
  fail "AC7 timeout" "message doesn't name CouchDB and the URL"
elif leaked "$canary"; then
  fail "AC7 timeout" "canary appears in output"
else
  ok "AC7 timeout (${took}s)"
fi

exit "$failed"
