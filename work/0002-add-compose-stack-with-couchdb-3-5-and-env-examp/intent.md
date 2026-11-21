---
id: 0002
title: Add compose stack with CouchDB 3.5 and .env.example
type: feature
status: draft
risk: low
tier: 
priority: P2
author: Mike Garabedian
created: 2026-11-21
branch: 
pr: 
depends: 0001, 0006
---
# Intent: Add compose stack with CouchDB 3.5 and .env.example

## Problem
No stack exists yet. Need compose.yaml (works with docker and podman compose) running couchdb:3.5 bound to localhost:5984, plus .env.example for admin user/password, vault list and Tailscale auth key (plan Phase 1, first step 1).

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
