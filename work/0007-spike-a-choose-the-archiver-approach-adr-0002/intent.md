---
id: 0007
title: Spike A: choose the archiver approach (ADR 0002)
type: chore
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
# Intent: Spike A: choose the archiver approach (ADR 0002)

## Problem
The archiver design is undecided. Evaluate an existing LiveSync file bridge or CLI first, then headless Obsidian, then a custom `_changes` reader, and record the choice, plus the E2EE key-on-server trade-off, in `docs/decisions/0002` (plan D1, D2, Phase 3). Until this is decided, Phase 3 can't start, and goal 2 (complete, durable history as plain Markdown in git) has no path. The choice also decides whether the stack fits ADR 0001's 1 GB memory budget on the shared Pi.

## Proposed outcome
- `docs/decisions/0002-archiver-approach.md` (ADR 0002, accepted) picks one archiver approach from (b) an existing LiveSync bridge or CLI, (a) headless Obsidian, or (c) a custom `_changes` reader. It records the options considered, with evidence for each: maintenance and release history, license, arm64 support, how it reads LiveSync's chunked and encrypted storage, how it tracks plugin-version changes, and its expected memory against the 1 GB budget.
- The ADR decides D2: whether the server holds each vault's E2EE passphrase (and how it's stored), or how the archive works without it. The trade-off is laid out and one option recommended.
- It says whether the choice needs a new language or runtime, with the justification CLAUDE.md's "boring tech" rule asks for.
- It states what Phase 3's implementation item must prove: the round-trip test (fixture vault → LiveSync → CouchDB → archiver → files → diff), the memory measurement on the Pi, and how plugin upgrades are detected.
- `docs/project-plan.md` D1 and D2 point at ADR 0002.

## Affected users and systems
- The owner's future history archive. No running code changes in this item.
- `docs/decisions/` (new ADR 0002) and `docs/project-plan.md` (D1, D2, Phase 3 notes).
- Constrains later work: the Phase 3 archiver item, `compose.yaml` and quadlets (a new service), `doctor`'s archiver-lag check, and the 1 GB budget from ADR 0001.

## Constraints
- Research only: docs, source repos, issues and release history. No prototype code is kept or run in this item.
- ADR 0001's memory budget: the archiver plus CouchDB plus the Tailscale sidecar fit in 1 GB on a 4 GB Pi shared with other services. If headless Obsidian is chosen, research alone can't prove that, so the ADR must make measuring it on the Pi a gate in the implementation item, and reopen ADR 0001 if it doesn't fit.
- It must run as a multi-arch (amd64 and arm64) container, rootless, and be expressible through podlet.
- Clients are sacred: the archiver only reads from CouchDB. It never writes to a vault database.
- Vaults are small (under 500 MB, mostly Markdown, few binaries), so plain git is assumed for the archive. The ADR notes this assumption.
- Secrets (vault passphrases, CouchDB credentials) never go in git or logs.

## Out of scope
- Building the archiver, its commit debounce, or the round-trip test (the Phase 3 implementation item).
- The archive remote: Forgejo, GitHub, or both (plan D4, a later item).
- Git LFS or other handling for large attachments, since vaults are small.
- CouchDB compaction and revision retention.

## Open questions
- [ ] Is there a maintained LiveSync file bridge or CLI today (option b)? Who maintains it, and does it track plugin releases?
- [ ] How stable is LiveSync's storage format (chunks, E2EE, path obfuscation) across plugin versions, and what does a version change cost options (b) and (c)?
- [ ] D2: hold the passphrase on the server, keep E2EE off (the transport is Tailscale-only and the host is the owner's), or archive somewhere else? The spike recommends one.

## Tier
standard — one ADR and a plan edit, research only; no running code or sensitive paths
