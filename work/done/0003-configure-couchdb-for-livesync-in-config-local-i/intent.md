---
id: 0003
title: Configure CouchDB for LiveSync in config/local.ini
type: feature
status: merged
risk: low
tier: standard
priority: P2
author: Mike Garabedian
created: 2026-11-21
branch: work/0003-configure-couchdb-for-livesync-in-config-local-i
pr: 5
depends: 0002, 0004
spec_hash: requirements=d36f9efcec51;acceptance-criteria=0f393705e26a;areas-of-concern=2be907f42787
started: 2026-11-22T18:51:10+00:00
submitted: 2026-11-22T21:41:13+00:00
submitted_verify: full
merged: 2026-11-22T21:51:17+00:00
checks: none
---
# Intent: Configure CouchDB for LiveSync in config/local.ini

## Problem
LiveSync needs CouchDB to have CORS, `require_valid_user`, `max_document_size` and `max_http_request_size` set. Add a `config/*.ini` with those settings, check it against the plugin's current docs, and confirm a Mac test vault syncs over localhost (project plan Phase 1, first steps 2 and 4). Today the 0002 stack runs CouchDB with only `single_node` set, so LiveSync can't connect, and nothing has proved the stack works for its actual purpose.

## Proposed outcome
- A LiveSync settings file in `config/`, beside `10-single-node.ini`, sets:
  - **CORS:** any origin for now, plus credentials, methods and headers as LiveSync's docs require. A backlog item tracks tightening it to Obsidian's origins.
  - **`require_valid_user`.**
  - **Document and request size limits** that match LiveSync's current recommendations, with the doc version cited.
- A test vault database and a dedicated non-admin CouchDB user, with access to that database only. They're made by documented, repeatable curl commands, so nothing syncs with the admin account. This mirrors what Phase 2's `vault add` will automate.
- A script checks the running CouchDB's live settings against the expected values, through CouchDB's config API, and fails on any mismatch.
- The owner follows a short checklist on the Mac, with a copy of the 0004 fixture vault opened in Obsidian:
  - LiveSync connects as the test user, with E2EE on and a throwaway passphrase.
  - LiveSync's own database-configuration check passes.
  - The vault syncs up.
  - An edit made in Obsidian reaches CouchDB.

  The result is recorded in the PR.

## Affected users and systems
- The owner, on the dev Mac (Obsidian with LiveSync), against the local rootless Podman stack.
- Changed: `config/` (a new ini), the README's "Run locally" section, the generated quadlets (if podlet output changes), and a new check script.
- 0005 builds on it (the same vault over Tailscale HTTPS from the iPhone).

## Constraints
- Set `[chttpd] require_valid_user = true`. Since 0002, `couchdb.env.example` leaves `COUCHDB_PASSWORD` empty, so an unedited copy fails closed only because the CouchDB image refuses to start without an admin. `require_valid_user` keeps anonymous requests out even if that upstream behaviour changes. Source: the security pass of 0002's nit review (PR #3), recorded in `work/done/0002-add-compose-stack-with-couchdb-3-5-and-env-examp/plan.md`.
- Follow 0002's config layout: settings go in a `config/*.ini` file beside `config/10-single-node.ini`. At start, compose's entrypoint wrapper copies them into CouchDB's `local.d/`. The file sorts before `docker.ini`, so the entrypoint's admin file stays last. The `config/local.ini` in this item's title predates that layout.
- Settings are checked against LiveSync's current docs and cited, not copied from older guides.
- The test user's password and the E2EE passphrase are throwaway values. They never appear in git, logs or the PR.
- **Test data only:** a copy-out of the 0004 fixture, never a real vault (CLAUDE.md Testing).
- CouchDB stays bound to loopback. HTTPS and other devices are 0005's job.
- ADR 0001's compose rules still hold, and `scripts/check-quadlets` still passes.

## Out of scope
- Tightening CORS to Obsidian's origins (a backlog item).
- The Tailscale sidecar, HTTPS and the iPhone (0005).
- Automating database and user creation, `init` and `vault add` (Phase 2).
- Settings presets and setup URIs (Phase 2).
- The archiver and round-trip tests (Phase 3).

## Open questions
- [ ] With CORS origins set to `*` and credentials enabled, does CouchDB 3.5 echo the request's origin, which LiveSync needs, or does the browser rule against `*` plus credentials break the mobile app's webview?
- [ ] Can LiveSync's settings be applied through the config file alone, or does LiveSync's own "fix" button write extra settings at runtime? Writes to `local.d/docker.ini` would drift from the repo.
- [ ] Should the check script live in `scripts/` as a reusable piece of the future `doctor` command, or stay a one-off test helper?
- [ ] Should the test database and user curl commands become a script now, or stay documented steps until `vault add`?

## Tier
standard — a new config file, a check script and a manual end-to-end test; auth-adjacent (require_valid_user, a non-admin user), so a spec is worth having
