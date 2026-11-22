---
id: 0006
title: Choose the container runtime and deployment model (ADR 0001)
type: chore
status: planned
risk: low
tier: standard
priority: P2
author: Mike Garabedian
created: 2026-11-21
branch: 
pr: 
depends: 
spec_hash: requirements=964f6cddf43a;acceptance-criteria=fc130b1ba8f1;areas-of-concern=e81742b90870
---
# Intent: Choose the container runtime and deployment model (ADR 0001)

## Problem
The plan assumes Podman on a Raspberry Pi 4 and "Docker or Podman" everywhere else, but never decides how liquid-sync is actually deployed and developed. The local machine runs Docker through Colima, while the Pi will run Fedora IoT with Podman. "Docker vs Podman locally" turned out to be the wrong question: the CLIs are nearly identical. What matters is how faithfully the laptop reproduces the Pi, and how one set of container definitions serves both without drifting. Until that's recorded, 0002 (the compose stack) can't be written with confidence.

## Proposed outcome
`docs/decisions/0001-container-runtime-and-deployment.md` records, with context, options and consequences:
- **Production host:** Fedora IoT on a Pi 4, with rootful Podman. Decided in discussion. Reasons: Pi 4 is an official reference platform, Podman/quadlets/`podman auto-update` are native, atomic updates with greenboot rollback, and controlled update windows (the Pi also serves household DNS). Rootful because co-hosted services need it (Pi-hole on port 53, a monitoring agent reading other containers), and it avoids rootless ownership and Tailscale-sidecar problems.
- **Shared host:** liquid-sync shares the Pi with other homelab services (Pi-hole, a monitoring agent, maybe one more). Those, and the OS provisioning, live in a separate private homelab repo. liquid-sync stays a portable, self-contained stack that assumes nothing about its neighbours.
- **Source of truth for container definitions:** one definition shared by local compose and the Pi's systemd setup, so the two can't drift. Not yet decided; this item chooses it.
- **Local development runtime:** what's used on macOS, and how `compose.yaml` is proven to work under Podman before work counts as done.
- **Compose compatibility rules** that keep `compose.yaml` working under both `docker compose` and `podman compose`.
- **Resource budget:** liquid-sync's expected memory footprint, so it fits alongside the other services on a 4 GB or 8 GB Pi 4 (the model is still undecided).

`docs/project-plan.md` is updated to match: D3 resolved, the "same Pi as other homelab services?" open question answered, and `deploy/pi/` described as a liquid-sync stack for any Fedora IoT host, not a whole-machine setup.

## Affected users and systems
- The owner, developing on macOS and running the Pi.
- `docs/decisions/` (new ADR), `docs/project-plan.md`.
- Downstream items: 0002 (compose stack), 0005 (Tailscale sidecar), and the later Pi deployment and backup/restore work.

## Constraints
- CLAUDE.md: `compose.yaml` works with both `docker compose` and `podman compose`; images are multi-arch and pinned; boring tech, and any new tool (e.g. a compose-to-quadlet generator) needs its own justification in the ADR.
- The repo is public: no homelab specifics (network layout, hostnames, other services' config) beyond naming the kinds of co-hosted services.
- Claims the ADR relies on are checked against current docs and cited. These came from memory in discussion and need checking: greenboot is part of Fedora IoT; Datadog-style agents need rootful Podman for full container visibility.
- Monitoring stays optional: liquid-sync must not require a Datadog account or any specific agent.

## Out of scope
- Writing `compose.yaml`, quadlets or any deployment code (0002 and later items).
- The homelab repo itself: OS provisioning, Pi-hole, the monitoring agent.
- Choosing the 4 GB vs 8 GB Pi (the ADR states liquid-sync's budget; the homelab picks the board).
- Alerting design. The owner wants it much smaller in scope for this project; that's a separate plan change.

## Open questions
- [ ] Source of truth: `compose.yaml` with quadlets generated from it, compose run under one systemd unit, or quadlets as the source with compose for development? What does each cost in tooling, and what does each lose (e.g. `podman auto-update`)?
- [ ] Local runtime: stay on Colima with Docker (current lean), or move to `podman machine`?
- [ ] How compose is proven under Podman before done: a manual step, a Linux container check like the one 0001 planned, or a CI job.
- [ ] What memory budget should liquid-sync target on a shared 4 GB Pi?

## Tier
standard — docs only with no sensitive paths, but the open questions need research and the owner's decision in the spec before the ADR is written.
