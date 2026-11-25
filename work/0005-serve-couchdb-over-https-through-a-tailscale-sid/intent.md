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
Clients need a stable private HTTPS hostname that moves with the stack. Today CouchDB is reachable only on `127.0.0.1:5984` on the Mac, so only the Mac can sync, and the iPhone can't reach it at all. That leaves Phase 1's "a Mac and an iPhone sync a test vault both ways" unfinished. Add a Tailscale sidecar with a dedicated node name, with `tailscale serve` in front of CouchDB, then confirm a Mac and an iPhone sync a test vault both ways (plan Phase 1, first step 4). ADR 0001 runs the sidecar rootless in userspace networking (no `/dev/net/tun` and no added capabilities). This item must prove that `tailscale serve` works in that mode, or reopen ADR 0001 (moved here from 0002).

## Proposed outcome
- The stack runs a Tailscale sidecar alongside CouchDB that joins the tailnet as its own node, `liquid-sync-dev`, while the stack runs on the dev Mac. The Pi claims `liquid-sync` later.
- `https://liquid-sync-dev.<tailnet>.ts.net` serves CouchDB with a valid Tailscale certificate, from any device on the tailnet.
- The Mac's test vault syncs over that HTTPS URL instead of localhost.
- The test vault on an iPhone syncs live with the Mac in both directions (Phase 1 done).
- Evidence that `tailscale serve` works in userspace mode under rootless Podman. If it doesn't, ADR 0001 is reopened.
- `docs/runbooks/local-sync-test.md` covers the HTTPS and iPhone steps.

## Affected users and systems
- The owner's Mac and iPhone, both on the tailnet, using the test vault from `test/fixtures/` only.
- `compose.yaml`, the generated `deploy/quadlets/`, a new `tailscale.env.example`, `README.md`, and `docs/runbooks/local-sync-test.md`.
- The tailnet: the node, its tag and its ACL. These are set up by 0010 (tailnet prerequisites), which this item depends on.

## Constraints
- ADR 0001's compose rules apply line by line, including the Tailscale one: `tailscale serve` only, never `funnel`; a tagged auth key; a tailnet ACL that limits access to the CouchDB port; and a state volume treated as secret.
- The sidecar is rootless with userspace networking: no `/dev/net/tun`, no added capabilities, no host ports below 1024.
- Auth is a one-time tagged auth key in a git-ignored `tailscale.env`. After the first login, the persisted state volume keeps the node logged in, and the key can expire.
- The memory limit fits ADR 0001's 1 GB total, together with CouchDB's 512m.
- The `quadlets` verify step from 0008 must pass, so the sidecar has to be expressible through podlet.
- No secret (auth key, node state, setup URI, CouchDB credentials) appears in logs, the runbook or commits.
- CouchDB stays bound to loopback on the host. The tailnet reaches it only through the sidecar.

## Out of scope
- Tailnet prerequisites: enabling MagicDNS and HTTPS certificates, creating the tag and its ACL. That is 0010, which this item depends on.
- Tightening CORS (0009), the CLI (Phase 2), setup URIs and QR codes, and real vaults.
- Deploying to the Pi and moving the node identity between hosts (Phase 5).

## Open questions
- [ ] Does `tailscale serve` in userspace mode proxy to another container by `container_name` on the compose network, or only to localhost? If only localhost, the sidecar may need CouchDB's network namespace (`network_mode: service:`), which ADR 0001 says must first be tested with podlet.
- [ ] Should the serve config be declarative (`TS_SERVE_CONFIG` JSON committed in `config/`) or set once with `tailscale serve --bg` and kept in the state volume? Declarative fits "no pets".
- [ ] Does keeping the `127.0.0.1:5984` host port still make sense once HTTPS works (for local scripts like `check-couchdb-config`), or should everything go through the sidecar?

## Tier
high — network exposure and infrastructure: a new tailnet node in front of CouchDB, plus a secret auth key and node state
