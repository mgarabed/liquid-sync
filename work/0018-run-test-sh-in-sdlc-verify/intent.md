---
id: 0018
title: Run test/*.sh in sdlc verify
type: chore
status: draft
risk: low
tier: 
priority: P2
author: Mike Garabedian
created: 2026-11-27
branch: 
pr: 
source: 0012
---
# Intent: Run test/*.sh in sdlc verify

## Problem
Script tests (0011's test-check-quadlets aside) can't join sdlc verify without a .sdlc/config.toml edit, which forces the high tier each time; add one generic verify step that runs every executable test/*.sh so later items add tests without touching control files.

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
