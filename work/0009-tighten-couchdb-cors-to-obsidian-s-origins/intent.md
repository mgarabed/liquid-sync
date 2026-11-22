---
id: 0009
title: Tighten CouchDB CORS to Obsidian's origins
type: feature
status: draft
risk: low
tier: 
priority: P3
author: Mike Garabedian
created: 2026-11-22
branch: 
pr: 
source: 0003
depends: 0003
---
# Intent: Tighten CouchDB CORS to Obsidian's origins

## Problem
0003 starts with CORS origins = * so LiveSync connects easily; restrict it to Obsidian's desktop and mobile origins (app://obsidian.md, capacitor://localhost, http://localhost) once sync works, so other web pages can't use stored credentials against CouchDB.

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
