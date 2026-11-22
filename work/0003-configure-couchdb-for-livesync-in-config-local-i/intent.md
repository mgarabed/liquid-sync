---
id: 0003
title: Configure CouchDB for LiveSync in config/local.ini
type: feature
status: draft
risk: low
tier: 
priority: P2
author: Mike Garabedian
created: 2026-11-21
branch: 
pr: 
depends: 0002, 0004
---
# Intent: Configure CouchDB for LiveSync in config/local.ini

## Problem
LiveSync needs CORS, require_valid_user, max_document_size and max_http_request_size set on CouchDB; add config/local.ini, check it against the plugin's current docs, and confirm a Mac test vault syncs over localhost (plan Phase 1, first steps 2 and 4).

## Proposed outcome
<!-- What "better" looks like, observable from the outside. -->

## Affected users and systems
<!-- Screens, modules, services, data stores, external APIs. -->

## Constraints
<!-- Must/must-not: platforms, auth, privacy, perf budgets, deadlines, things not to touch. -->
- Set `[chttpd] require_valid_user = true`. Since 0002, `couchdb.env.example` leaves `COUCHDB_PASSWORD` empty, so an unedited copy fails closed only because the CouchDB image refuses to start without an admin. `require_valid_user` keeps anonymous requests out even if that upstream behaviour changes. Source: the security pass of 0002's nit review (PR #3), recorded in `work/done/0002-add-compose-stack-with-couchdb-3-5-and-env-examp/plan.md`.
- Follow 0002's config layout: settings go in a `config/*.ini` file beside `config/10-single-node.ini`. At start, compose's entrypoint wrapper copies them into CouchDB's `local.d/`. The file sorts before `docker.ini`, so the entrypoint's admin file stays last. The `config/local.ini` in this item's title predates that layout.

## Out of scope
<!-- Explicitly not doing. -->

## Open questions
<!-- One per line as "- [ ] question". Answer inline ("- [x] q — answer") or defer to spec. -->

## Tier
<!-- The tier this change needs (patch, small, standard, full or high) and a one-line reason, e.g. "small — two
files, no sensitive paths". The intent skill asks you; the first accept records it. -->
