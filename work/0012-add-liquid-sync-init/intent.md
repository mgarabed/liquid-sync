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
depends: 0011, 0016
---
# Intent: Add liquid-sync init

## Problem
Phase 2: ./liquid-sync init generates the per-service *.env files from their examples, starts the stack, applies CouchDB config idempotently, and waits for health; bash, set -euo pipefail, shellcheck, --help, --dry-run.

Rescoped 2026-11-27 (twice), for the host bundle contract (ADR 0003), 0011 and 0017. Most of the original job is now done elsewhere:
- **CouchDB config:** declared in `config/*.ini`, loaded when the container starts (0003) and shipped in the bundle (0011). Nothing is left to apply through the HTTP API.
- **On a host:** the host tool writes `couchdb.env` and starts the units. 0017's health check, with `Notify=healthy`, covers health, and 0015's `doctor` covers config drift.
- **Upstream:** the LiveSync CLI is a vault sync client with no server-admin commands, and upstream's `couchdb-init.sh` only applies config through the API. So neither replaces anything here.

Two things are still missing. There's no `./liquid-sync` entry point, though README already lists `./liquid-sync init`, and 0013–0015 all add subcommands to it. And setting up a local stack means copying the env example by hand, which leaves its fake admin password in place.

## Proposed outcome
- A `./liquid-sync` CLI at the repo root:
  - subcommand dispatch, with `--help` for the tool and for each subcommand;
  - a shared `--dry-run`;
  - shared helpers that 0013–0015 reuse: reading credentials from an env file without sourcing it, authenticated calls to CouchDB with credentials kept out of argv, waiting for health, and errors without secrets.
- `./liquid-sync init`, for local development only:
  - If `couchdb.env` is missing, create it from `couchdb.env.example` with mode 0600. It keeps the example's username and replaces the password with a strong random one. The password is never printed.
  - If `couchdb.env` exists, leave it untouched and don't print it.
  - Start the stack with `podman compose up -d`, wait for an authenticated `_up`, and run the config drift check (`scripts/check-couchdb-config`).
  - A second run changes nothing and reports that everything is already in place.
  - `--dry-run` says which of these it would do, without doing any of them.
- README's commands section matches what exists, and `docs/project-plan.md`'s Phase 2 line no longer says init applies config through the HTTP API.

## Affected users and systems
- New: `./liquid-sync`, and any helper library it sources, plus its tests.
- `couchdb.env.example` (read), the git-ignored `couchdb.env` (created only when missing), `compose.yaml` (run, not changed) and `scripts/check-couchdb-config` (called).
- `README.md`, and `docs/runbooks/local-sync-test.md` if it can start with `./liquid-sync init` instead of hand steps.
- The local stack on the dev Mac (Podman machine). Nothing on the production host.

## Constraints
- bash with `set -euo pipefail`, passes `shellcheck`, idempotent, `--help` on every subcommand, `--dry-run` for anything that changes data (CLAUDE.md).
- Secrets: the generated password and the contents of `couchdb.env` never reach stdout, stderr, logs, argv or the repo. An existing `couchdb.env` is never overwritten, recreated or printed.
- The password comes from standard tools reading `/dev/urandom`. No new dependency.
- Local development uses `podman` commands, never `docker`, and leaves the Colima setup alone (ADR 0001).
- CouchDB is reached only on `127.0.0.1:5984`.
- Test against a throwaway vault in `test/fixtures/` only, and never against a real `couchdb.env`. Tests use a temp directory.

## Out of scope
- `deploy/hooks/post-install`. The contract makes it optional, and today it would only repeat 0017's health check and 0015's drift check. Add it when there's a real migration.
- Any host path or host detection: init is local only.
- `vault add/list/remove` (0013), `setup-uri` (0014) and `doctor` (0015), apart from the shared helpers they'll use.
- Rotating an existing admin password.

## Open questions
- [x] Is post-install a thin wrapper around a shared init script, or a separate script? — Neither: there's no post-install hook in this item (Out of scope).
- [x] How does init tell the local path from the host path? — It doesn't need to: init is local only.
- [x] What counts as a migration? — None exist. A hook point waits for the first real migration.
- [x] What admin username does a generated `couchdb.env` get? — The example's username; only the password is generated.
- [ ] One script file, or `./liquid-sync` plus a sourced `lib/` of helpers that later subcommands share? Decide in the spec.

## Tier
standard — one feature, local only: a new CLI script, its tests and docs, with no deploy or control files.
