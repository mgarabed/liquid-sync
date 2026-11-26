---
id: 0010
title: Prepare the tailnet for liquid-sync
type: chore
status: draft
risk: low
tier: 
priority: P2
author: Mike Garabedian
created: 2026-11-25
branch: 
pr: 
source: 0005
---
# Intent: Prepare the tailnet for liquid-sync

## Problem
Enable MagicDNS and HTTPS certificates, add tag:liquid-sync with tagOwners, and an ACL limiting tailnet access to the node's HTTPS port; decide where that policy is declared (this repo, the homelab repo, or the console). 0005 depends on it.

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
