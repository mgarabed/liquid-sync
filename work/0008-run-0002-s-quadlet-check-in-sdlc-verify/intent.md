---
id: 0008
title: Run 0002's quadlet check in sdlc verify
type: chore
status: draft
risk: low
tier: 
priority: P2
author: Mike Garabedian
created: 2026-11-22
branch: 
pr: 
source: 0002
depends: 0002
---
# Intent: Run 0002's quadlet check in sdlc verify

## Problem
ADR 0001's podlet check (regenerate quadlets, diff, quadlet -dryrun -user) exists as a script from 0002 but isn't a step in .sdlc/config.toml, so sdlc verify doesn't catch compose/quadlet drift; this is control plane, so it needs the high tier.

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
