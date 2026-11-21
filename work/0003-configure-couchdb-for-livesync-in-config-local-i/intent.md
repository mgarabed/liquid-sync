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

## Out of scope
<!-- Explicitly not doing. -->

## Open questions
<!-- One per line as "- [ ] question". Answer inline ("- [x] q — answer") or defer to spec. -->

## Tier
<!-- The tier this change needs (patch, small, standard, full or high) and a one-line reason, e.g. "small — two
files, no sensitive paths". The intent skill asks you; the first accept records it. -->
