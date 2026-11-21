---
id: 0001
title: Block personal and secret leaks before commit and push
type: chore
status: draft
risk: low
tier: 
priority: P1
author: Mike Garabedian
created: 2026-11-21
branch:
pr:
---
# Intent: Block personal and secret leaks before commit and push

## Problem
This repo is public; nothing stops a commit or push containing secrets (setup URIs, tskey- keys, credentialed CouchDB URLs, .env values) or personal data (email, tailnet name, home hostnames/subnet, author emails). Need one bash check run by committed pre-commit/pre-push hooks and as an sdlc verify step, with generic patterns in-repo and personal patterns in a file outside the repo; the hook also runs shellcheck (plan Phase 2).

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
