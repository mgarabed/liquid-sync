---
id: 0012
title: Add liquid-sync init
type: feature
status: draft
risk: low
tier: 
priority: P2
author: Mike Garabedian
created: 2026-11-26
branch:
pr:
---
# Intent: Add liquid-sync init

## Problem
Phase 2: ./liquid-sync init generates the per-service *.env files from their examples, starts the stack, applies CouchDB config idempotently, and waits for health; bash, set -euo pipefail, shellcheck, --help, --dry-run.

Rescoped 2026-11-27 for the host bundle contract (`docs/decisions/0003-host-bundle-contract.md`). On a host, the host tool writes `couchdb.env` and starts the units. It then runs `deploy/hooks/post-install` on every apply, as the service user, from the installed quadlet directory. So init has two callers. On a host, init is (or is called by) post-install: it waits for health, then applies the CouchDB config and any migration. Locally, `./liquid-sync init` also generates the env files from their examples and starts the stack.

## Proposed outcome
- `./liquid-sync init` on the dev Mac generates any missing `*.env` file from its example, starts the stack, waits for CouchDB to be healthy, and applies the CouchDB config through its HTTP API. A second run changes nothing.
- `deploy/hooks/post-install`, run by the host tool after the units are running, waits for health and applies the same CouchDB config and any migration. It is non-interactive, idempotent, and exits non-zero on failure.
- On any host, an existing `couchdb.env` is never created, overwritten or printed. Generating env files from their examples is a local-dev path only.
- `--help` on every path, and `--dry-run` shows what would change without changing it.

## Affected users and systems
- New: the `./liquid-sync` CLI script at the repo root, and `deploy/hooks/post-install`.
- Helper files the hook needs, in `deploy/quadlets/`, because the hook's working directory is the installed quadlet directory and the repo isn't on the host.
- `couchdb.env.example`, `config/*.ini` (or their copies under `deploy/quadlets/config/`, per 0011), and `scripts/check-couchdb-config`.
- CouchDB on the dev Mac and on the production Pi.

## Constraints
- bash with `set -euo pipefail`, passes `shellcheck`, idempotent, `--help`, `--dry-run` for anything that changes data.
- Hooks only read env files. Every secret, including the CouchDB admin password, comes from an env file the host supplies. Secrets are never printed or logged.
- The hook gets `STACK_NAME` and `STACK_URL` in its environment, and a working user session for `podman` and `systemctl --user`. It must not assume the repo, compose or the `./liquid-sync` script exist on the host.
- Nothing needs root. CouchDB is reached only on `127.0.0.1:5984`.
- Test against a throwaway vault in `test/fixtures/` only.

## Out of scope
- `vault add/list/remove` (0013), `setup-uri` (0014) and `doctor` (0015).
- `deploy/hooks/backup` and `deploy/hooks/restore` (Phase 5).
- Shipping the bundle layout and its checks (0011).
- Tightening CORS (0009).

## Open questions
- [ ] Is post-install a thin wrapper around a shared init script shipped in `deploy/quadlets/`, with `./liquid-sync init` adding the local-only steps around it? Or is it a separate script that shares a library?
- [ ] How does init tell the local-dev path from the host path: a flag, the `STACK_NAME` env var, or the hook entry point alone?
- [ ] What counts as a migration at this point? There's nothing to migrate yet, so is a migration hook point enough for now?

## Tier
full — a new CLI and a hook that run on the production host with the CouchDB admin secret; review the spec before planning.
