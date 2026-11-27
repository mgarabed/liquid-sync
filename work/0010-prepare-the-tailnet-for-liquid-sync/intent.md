---
id: 0010
title: Tailnet prerequisites provided by homelab ADR 0005
type: chore
status: in-review
risk: low
tier: 
priority: P2
author: Mike Garabedian
created: 2026-11-25
branch: work/0010-prepare-the-tailnet-for-liquid-sync
pr: 8
source: 0005
spec_hash: requirements=f49f8cce55a0;acceptance-criteria=b55ab3396673;areas-of-concern=3921a6d58d1d
started: 2026-11-27T13:26:53+00:00
submitted: 2026-11-27T13:31:42+00:00
submitted_verify: full
---
# Intent: Tailnet prerequisites provided by homelab ADR 0005

## Problem
0005 needs a tailnet that can serve CouchDB over private HTTPS. That means MagicDNS, HTTPS certificates, a host allowed to publish liquid-sync, and a policy that limits who can reach it. This item originally planned to set that up and to decide where the policy lives.

That decision is made. Homelab ADR 0005 (accepted 2026-11-26) publishes liquid-sync as the Tailscale Service `svc:liquid-sync`, and the homelab repo owns the tailnet policy (`tailscale/policy.hujson`, with tests). This repo configures nothing on the tailnet. This item now records the dependency and confirms the prerequisites are in place before 0005 relies on them.

## Proposed outcome
These prerequisites are in place, all provided by the homelab repo under homelab ADR 0005:
- MagicDNS and HTTPS certificates are on for the tailnet.
- `svc:liquid-sync` exists and resolves as `https://liquid-sync.<tailnet>.ts.net` on 443.
- Only `tag:server` hosts may advertise `svc:liquid-sync`. The production Pi is tagged `tag:server` and is the first host to advertise it.
- The policy lets only the owner's user reach `svc:liquid-sync`, and only on 443. Funnel is not allowed.
- On each Service host, homelab applies the serve config: `tailscale serve` terminates TLS and forwards to `127.0.0.1:5984`.

On the liquid-sync side:
- The docs (README, project plan and runbook) point to homelab ADR 0005 for publishing and the tailnet policy, instead of describing a sidecar. README and the project plan were updated 2026-11-26; the runbook is written by 0005.
- 0005 can start once this item is closed.

## Affected users and systems
- The tailnet and the production Pi, both managed from the homelab repo.
- In this repo, docs only: `README.md`, `docs/project-plan.md`, and the runbook that 0005 writes.

## Constraints
- This repo never edits the tailnet policy, never runs `tailscale`, and never stores Tailscale credentials. The liquid-sync service user never controls tailscaled.
- The real tailnet name never appears in this repo. Write `<tailnet>`.
- Always write "homelab ADR 0005" in full, so it isn't confused with work item 0005 or with this repo's own ADRs.

## Out of scope
- Writing or testing the tailnet policy. That lives in homelab's `tailscale/policy.hujson` and is live.
- Serving the Mac's local stack over the tailnet. A Mac signed in as a user can't host a Service, so local development stays on localhost.
- The end-to-end sync test with the Mac and the iPhone. That is 0005.

## Open questions
- [x] Is the homelab policy file merged and applied, with its tests passing? — Yes, as of 2026-11-26: homelab's tailnet policy is live (tests pass), the production Pi is tagged `tag:server`, and MagicDNS and HTTPS certificates are on. Still to come: the Pi advertising `svc:liquid-sync` and applying the serve config, which needs the stack running there (0011).
- [ ] How does this repo confirm the prerequisites without being able to read the homelab repo? Options are a manual checklist in the runbook (`curl` from a tailnet device, a denied port, a non-owner device), or a later `doctor` check (0015).

## Tier
<!-- Recorded at first accept. -->
