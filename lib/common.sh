#!/usr/bin/env bash
# Shared helpers for liquid-sync's bash scripts. Source it; don't run it.
# It defines functions only and sets no shell options: callers own
# `set -euo pipefail`.
#
# Callers set PROG (the prefix for die and warn) before using these. Helpers
# that talk to CouchDB read the curl credentials line from COUCH_AUTH, which
# curl_auth_line builds. It goes to curl on stdin, never in argv.

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  echo "lib/common.sh is sourced by liquid-sync's scripts, not run" >&2
  exit 1
fi

die() { echo "${PROG:-liquid-sync}: $*" >&2; exit 1; }
warn() { echo "${PROG:-liquid-sync}: warning: $*" >&2; }
info() { printf '%s\n' "$*"; }

# Print the value of KEY from an env file without sourcing the file.
# Usage: env_value FILE KEY
env_value() {
  local line
  line="$(grep -E "^$2=" "$1" | tail -n 1)" || return 1
  line="${line#*=}"
  # Strip one pair of surrounding quotes, as compose's env_file does.
  case "$line" in
    \"*\") line="${line:1:${#line}-2}" ;;
    \'*\') line="${line:1:${#line}-2}" ;;
  esac
  printf '%s' "$line"
}

# Print a curl config line holding the credentials. Backslashes and double
# quotes are escaped for curl's quoted-string syntax.
# Usage: COUCH_AUTH="$(curl_auth_line USER PASS)"
escape() { local s="${1//\\/\\\\}"; printf '%s' "${s//\"/\\\"}"; }
curl_auth_line() { printf 'user = "%s:%s"' "$(escape "$1")" "$(escape "$2")"; }

# GET URL/PATH with the COUCH_AUTH credentials. Extra arguments go to curl;
# a later --max-time overrides the default. Credentials go to curl on stdin
# (--config -), never in argv, so they don't show in ps.
# Usage: couch_get URL PATH [curl args...]
couch_get() {
  local url="$1" path="$2"
  shift 2
  printf '%s\n' "$COUCH_AUTH" \
    | curl -sS --max-time 10 --config - "$@" "$url$path"
}

# The podman binary: $PODMAN, else podman on PATH, else the macOS .pkg
# installer's /opt/podman/bin/podman.
podman_bin() {
  if [ -n "${PODMAN:-}" ]; then
    printf '%s\n' "$PODMAN"
  elif command -v podman >/dev/null 2>&1; then
    command -v podman
  else
    printf '%s\n' /opt/podman/bin/podman
  fi
}

# Poll URL/_up every 2 s with the COUCH_AUTH credentials until it returns 200.
# Returns 1 on timeout. Dies at once on 401 or 403, so a container still
# running on an older password doesn't look like a slow start.
# Usage: wait_for_couch URL TIMEOUT_SECONDS
wait_for_couch() {
  local url="$1" timeout="$2" start status
  start="$SECONDS"
  while :; do
    status="$(couch_get "$url" /_up --max-time 2 -o /dev/null -w '%{http_code}' \
      </dev/null 2>/dev/null)" || status="000"
    case "$status" in
      200) return 0 ;;
      401|403) die "CouchDB refused the admin credentials (HTTP $status)" ;;
    esac
    [ $((SECONDS - start)) -lt "$timeout" ] || return 1
    sleep 2
  done
}
