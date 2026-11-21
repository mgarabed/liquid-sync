---
id: 0005
title: Serve CouchDB over HTTPS through a Tailscale sidecar
type: feature
status: draft
risk: low
tier: 
priority: P2
author: Mike Garabedian
created: 2026-11-21
branch: 
pr: 
depends: 0003
---
# Intent: Serve CouchDB over HTTPS through a Tailscale sidecar

## Problem
Clients need a stable private HTTPS hostname that moves with the stack; add a Tailscale sidecar with a dedicated node name and tailscale serve in front of CouchDB, then confirm a Mac and an iPhone sync a test vault both ways (plan Phase 1, first step 4).

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
