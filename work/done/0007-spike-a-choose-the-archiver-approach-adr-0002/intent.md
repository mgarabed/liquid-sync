---
id: 0007
title: Spike A: choose the archiver approach (ADR 0002)
type: chore
status: merged
risk: low
tier: standard
priority: P2
author: Mike Garabedian
created: 2026-11-21
branch: work/0007-spike-a-choose-the-archiver-approach-adr-0002
pr: 7
depends: 0003
spec_hash: requirements=e980e6e8a5e3;acceptance-criteria=0dadab42db4b;areas-of-concern=f965e15c7e4a
started: 2026-11-26T14:21:30+00:00
submitted: 2026-11-26T14:35:01+00:00
submitted_verify: full
merged: 2026-11-26T15:00:10+00:00
checks: none
---
# Intent: Spike A: choose the archiver approach (ADR 0002)

## Problem
The archiver design is undecided. Evaluate an existing LiveSync file bridge or CLI first, then headless Obsidian, then a custom `_changes` reader, and record the choice, plus the E2EE key-on-server trade-off, in `docs/decisions/0002` (plan D1, D2, Phase 3). Until this is decided, Phase 3 can't start, and goal 2 (complete, durable history as plain Markdown in git) has no path. The choice also decides whether the stack fits ADR 0001's 1 GB memory budget on the shared Pi.

## Proposed outcome
- `docs/decisions/0002-archiver-approach.md` (ADR 0002, accepted) picks one archiver approach from (b) an existing LiveSync bridge or CLI, (a) headless Obsidian, or (c) a custom `_changes` reader, and weighs (d) LiveSync's own suggested backup plugin, [Differential ZIP Backup](https://github.com/vrtmrz/diffzip), either as the archive or as a complement to it. It records the options considered, with evidence for each: maintenance and release history, license, arm64 support, how it reads LiveSync's chunked and encrypted storage, how it tracks plugin-version changes, and its expected memory against the 1 GB budget.
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
- [ ] Where does Differential ZIP Backup fit? From its README (read 2026-11-26): it's an MIT-licensed Obsidian plugin that runs only inside an Obsidian client, with no server or CLI part. It writes differential ZIPs, with an optional AES-256 passphrase, to a vault folder, a desktop path or an S3-compatible bucket. It keeps per-file revisions with a restore UI, and the README doesn't mention LiveSync. Because it works on the decrypted vault on a client, it sidesteps D2. But it produces ZIPs rather than browsable Markdown in git (goal 2), and it needs Obsidian running. Candidate roles to weigh: the archiver itself, a plugin inside a headless Obsidian (option a) instead of Obsidian Git, or a separate client-side disaster-recovery backup that feeds Phase 5's `backup` plan.
- [ ] D2: hold the passphrase on the server, keep E2EE off (the transport is Tailscale-only and the host is the owner's), or archive somewhere else? The spike recommends one.

## Tier
standard — one ADR and a plan edit, research only; no running code or sensitive paths
