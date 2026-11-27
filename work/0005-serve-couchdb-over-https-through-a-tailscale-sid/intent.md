---
id: 0005
title: Sync a Mac and an iPhone over HTTPS through svc:liquid-sync
type: feature
status: draft
risk: low
tier: 
priority: P2
author: Mike Garabedian
created: 2026-11-21
branch: 
pr: 
depends: 0003, 0010, 0011
---
# Intent: Sync a Mac and an iPhone over HTTPS through svc:liquid-sync

## Problem
Clients need a stable private HTTPS hostname that doesn't change when the stack moves to another host. Today CouchDB is reachable only on `127.0.0.1:5984`. The Mac can sync over localhost, but the iPhone can't reach CouchDB at all. That leaves Phase 1's "a Mac and an iPhone sync a test vault both ways" unfinished (plan Phase 1, first step 4).

Rescoped 2026-11-26 after homelab ADR 0005 (accepted 2026-11-26). liquid-sync is now published as the Tailscale Service `svc:liquid-sync` at `https://liquid-sync.<tailnet>.ts.net` on port 443. The host's own `tailscale serve` terminates TLS and forwards to `127.0.0.1:5984`. The homelab repo owns publishing: which hosts advertise the Service, the serve config, and the tailnet policy. The stack only has to bind CouchDB to 127.0.0.1, which it already does. The earlier design, a Tailscale sidecar with its own `liquid-sync-dev` node, is dropped. That removes the auth key, the state volume and the userspace-serve proof.

A Mac signed in as a user can't host a Service, so local development stays on localhost. The end-to-end test runs against the production Pi, the first Service host.

## Proposed outcome
- `https://liquid-sync.<tailnet>.ts.net` serves CouchDB from the production Pi with a valid Tailscale certificate. It is reachable from the owner's devices on 443 only.
- The first live check of what homelab ADR 0005 provides: the Pi advertises `svc:liquid-sync`, its serve config forwards 443 to `127.0.0.1:5984`, and other ports on the Service are refused (handed over from 0010).
- The Mac's test vault syncs over that URL instead of localhost.
- The test vault on an iPhone syncs live with the Mac in both directions, both going through the Pi (Phase 1 done).
- `docs/runbooks/local-sync-test.md` covers the HTTPS and iPhone steps, and says that local development on the Mac stays on `http://127.0.0.1:5984`.

## Affected users and systems
- The owner's Mac and iPhone, on the tailnet, using the test vault from `test/fixtures/` only.
- The production Pi, running the stack deployed by 0011 (this item depends on it).
- `docs/runbooks/local-sync-test.md`, and `README.md` where it describes how the stack is published.
- `compose.yaml` is expected to stay as it is: CouchDB already binds only to `127.0.0.1:5984`. If the test shows that a change is needed, the change follows ADR 0001's compose rules.
- The tailnet: the Service, its host tag and its policy. homelab ADR 0005 provides these, tracked by 0010.

## Constraints
- This repo never runs `tailscale` and never controls tailscaled. The liquid-sync service user holds no Tailscale credentials. Publishing belongs to the homelab repo.
- CouchDB stays bound to loopback on the host. The tailnet reaches it only through the host's `tailscale serve` on `svc:liquid-sync`. There is no Funnel.
- No sidecar. Under the host bundle contract (ADR 0003, added by 0016), the stack exposes only `127.0.0.1:5984`, and the host publishes `svc:liquid-sync`.
- No secret (CouchDB credentials, setup URI) appears in logs, the runbook or commits. The runbook writes the tailnet name as `<tailnet>`.
- Test against the throwaway vault only, never a real vault. No step may risk data on a client device.

## Out of scope
- Tailnet prerequisites: MagicDNS, HTTPS certificates, the `tag:server` tag, advertising `svc:liquid-sync`, and the policy. These belong to homelab ADR 0005 and are tracked by 0010.
- Deploying the stack to the Pi. That is 0011, which this item depends on.
- Tightening CORS (0009), the CLI (Phase 2), setup URIs and QR codes, and real vaults.
- Serving the Mac's local stack over the tailnet.
- Moving the Service between hosts (Phase 5).

## Open questions
- [x] Does keeping the `127.0.0.1:5984` host port still make sense once HTTPS works? — Yes. It is what the host's `tailscale serve` forwards to, and local scripts like `check-couchdb-config` use it too.

## Tier
high — this is the first time CouchDB is reachable from other devices on the tailnet, even though the homelab repo owns the exposure. The rescope removed the earlier reasons (a new node, an auth key and node state), so standard may be enough.
