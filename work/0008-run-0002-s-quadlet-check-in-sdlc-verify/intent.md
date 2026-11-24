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
ADR 0001's podlet check (regenerate the quadlets from `compose.yaml`, diff them against `deploy/quadlets/`, then `quadlet -dryrun -user`) exists as `scripts/check-quadlets` from 0002, but it isn't a step in `.sdlc/config.toml`. Today `sdlc verify` runs only shellcheck, so an edit to `compose.yaml` that leaves the committed quadlets stale, or that podlet or quadlet rejects, still ends with "verify: PASS". This matters now because 0005 adds a second service (the Tailscale sidecar) to `compose.yaml`. ADR 0001 says 0002 would add this step; it didn't.

## Proposed outcome
- `sdlc verify` and `sdlc verify --fast` both run the quadlet check after shellcheck.
- A `compose.yaml` change without a matching `scripts/check-quadlets --write` makes verify fail, and the output says to run `--write` and review the diff.
- When Podman isn't available (not installed, not on PATH, or the machine is stopped), the step is skipped with a clear warning that the quadlet check didn't run, and verify can still pass.
- ADR 0001's "Podman compatibility" line matches what verify actually does, including the skip.

## Affected users and systems
- The owner, and agents building items, who run `sdlc verify` on the dev Mac (Podman machine, `podman` on PATH through `~/.zshrc`).
- Contributors without Podman, who see the skip warning instead of a failure.
- `.sdlc/config.toml` (control plane), possibly `scripts/check-quadlets`, and `docs/decisions/0001-container-runtime-and-deployment.md`.

## Constraints
- Control-plane change: `.sdlc/config.toml` is a gated file.
- Finding Podman relies on PATH or the script's existing `PODMAN` variable. No hard-coded `/opt/podman` fallback.
- Must keep working with the tooling images pinned by digest. A first run pulls them; later runs take under a second.
- The check never reads a real secret (it already stages `couchdb.env.example`); keep it that way.
- The skip must say so loudly. A skipped check must not look like a pass.

## Out of scope
- A GitHub Actions workflow running verify on PRs (its own item, possibly together with gitleaks).
- Changing what the check validates, or bumping podlet or podman image versions.
- Deploying to the Pi (the Phase 5 deployment item).

## Open questions
- [ ] Skipping when Podman is missing means drift can reach main unseen until CI exists. Should the skip be distinguishable from "Podman present but broken" (e.g. machine stopped vs. podlet error), so a real failure never turns into a skip?
- [ ] Does the skip belong in `scripts/check-quadlets` itself (e.g. a flag) or in the verify step's command?

## Tier
high — edits .sdlc/config.toml, a control-plane file sdlc always counts as sensitive
