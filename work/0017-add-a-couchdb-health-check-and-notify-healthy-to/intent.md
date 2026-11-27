---
id: 0017
title: Add a CouchDB health check and Notify=healthy to the quadlet
type: feature
status: draft
risk: low
tier: 
priority: P2
author: Mike Garabedian
created: 2026-11-27
branch:
pr:
---
# Intent: Add a CouchDB health check and Notify=healthy to the quadlet

## Problem
ADR 0003 promises that each auto-updated .container sets Notify=healthy with a health check, so podman auto-update can roll back an unhealthy image. couchdb.container sets AutoUpdate=registry with neither. The CouchDB 3.5 image has no curl (0002), compose has no field for Notify=, and require_valid_user means _up needs credentials, so it needs its own design. Deferred from 0011.

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
