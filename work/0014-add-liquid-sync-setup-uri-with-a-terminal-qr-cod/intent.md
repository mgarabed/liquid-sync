---
id: 0014
title: Add liquid-sync setup-uri with a terminal QR code
type: feature
status: draft
risk: low
tier: 
priority: P2
author: Mike Garabedian
created: 2026-11-26
branch: 
pr: 
depends: 0005, 0012, 0013
---
# Intent: Add liquid-sync setup-uri with a terminal QR code

## Problem
Phase 2: generate an encrypted LiveSync setup URI per vault and profile (desktop, mobile) with a one-time passphrase, and print a terminal QR code; the URI is a secret and is never logged or written to the repo.

Finding, 2026-11-27: upstream has no setup-URI generator to call. This was checked against the LiveSync repo at the commit `config/20-livesync.ini` pins (70899e2). There is no standalone generator script, despite `docs/project-plan.md`'s component table. The LiveSync CLI can only apply a URI (`setup <setupURI>`), not create one, and the plugin generates one only from a client that's already configured. So liquid-sync has to build the encrypted URI itself. Its format is defined in the plugin's `src/serviceFeatures/setupObsidian/setupUri.ts`, which has unit tests. The CLI's `setup` command can then check a generated URI by applying it. The repo also has a design doc, `docs/design_docs/time_bound_setup_uri.md`, which may change the format.

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
- [ ] How do we generate the URI without owning a copy of an internal format? Options: reimplement `setupUri.ts`'s encoding in bash with standard tools, or run the plugin's own code in the pinned CLI image. The format may move to time-bound URIs (`time_bound_setup_uri.md`).
- [ ] How does a test prove a generated URI works? Proposed: apply it with the pinned CLI's `setup` command against a throwaway vault, then `sync`.
- [ ] Fix `docs/project-plan.md`'s "LiveSync ships a generator script" line in this item, or in an earlier docs change?

## Tier
<!-- The tier this change needs (patch, small, standard, full or high) and a one-line reason, e.g. "small — two
files, no sensitive paths". The intent skill asks you; the first accept records it. -->
