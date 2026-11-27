---
id: 0010
title: Tailnet prerequisites provided by homelab ADR 0005
stage: spec
from: intent.md
---
# Spec: Tailnet prerequisites provided by homelab ADR 0005

## Areas of concern
- [x] The doc edits this item delivers were drafted ahead of time, on main, in the session that relayed homelab ADR 0005: `README.md`, `docs/project-plan.md`, ADR 0001 and ADR 0002. — They are 0010's change, and must reach main through 0010's branch and PR, not as a direct commit. The build runs in its own worktree, so uncommitted edits in this checkout wouldn't follow it. — They are parked in the git stash `0010 docs: homelab ADR 0005 publishing model`, which every worktree of this repo can see. The build applies it first (`git stash list`, then `git stash apply` with that entry), checks the result against this spec, and drops the stash once the branch commits it. The 0005 intent edit is not part of this item: it was committed on main as a draft-intent change. — decided: stash to the 0010 branch.
- [x] This repo can't read the homelab repo or the tailnet policy. So it can't check for itself that the policy is live, that the Pi is tagged `tag:server`, or that MagicDNS and HTTPS certificates are on. — An item that "confirms the prerequisites" has nothing it can actually run. — Accept homelab's own check: its policy tests pass, and the owner relayed the result on 2026-11-26, recorded in intent.md. The first live check from this side is the Pi advertising `svc:liquid-sync` and serving CouchDB, and that needs the stack deployed (0011). So it moves to 0005's runbook (R6), and 0010 doesn't wait for it. — decided: accept homelab's tests.
- [x] Public repo: no personal hostnames, device names or the real tailnet name (owner's rule, 2026-11-26). — An acceptance criterion can't name the machine it checks for without leaking it. — decided: no special check. Machine names are simply never written, and hosts are referred to by generic names (the Pi, the production Pi, the Service host). The tailnet is written as `<tailnet>`.
- [x] ADR 0001 says a wrong decision "is superseded by a new ADR, not edited", but this item amends it in place. — decided: the owner asked on 2026-11-26 for an amendment, not a new ADR. 0008 set the precedent: dated "Amended 2026-11-26" notes, with the Evidence section left as recorded.
- [x] Tier `full` is heavy for a docs-only chore. — decided: no change from this spec. The owner set the tier at accept, and `sdlc tier 0010` can lower it.

## Requirements
- R1. `README.md` describes publishing as the Tailscale Service `svc:liquid-sync`, owned by the homelab repo under homelab ADR 0005. It doesn't mention a Tailscale sidecar.
- R2. `docs/project-plan.md` describes the same model wherever Tailscale access comes up:
  - the components table (Tailscale access, Pi deployment);
  - host migration (5.3);
  - Phase 1 (env files, HTTPS);
  - first step 4.
  It mentions no sidecar, no Tailscale auth key and no per-host node name.
- R3. ADR 0001 is amended in place, with dated notes. None of the decisions, compose rules or consequences outside Evidence requires a Tailscale container, auth key, state volume or userspace networking.
  - The decisions state that the stack is published as `svc:liquid-sync` on 443, through the host's own `tailscale serve`, forwarding to `127.0.0.1:5984`.
  - The Tailscale compose rule limits access to 443 on `svc:liquid-sync`.
  - The host is described as an 8 GB Pi 4 booting from a USB flash drive.
  - The Evidence section is unchanged.
- R4. ADR 0002's memory-budget context says the Pi has 8 GB, with a dated note that the 1 GB budget is unchanged.
- R5. Files changed by this item refer to hosts and devices only by generic names (the Pi, the production Pi, the Service host, the owner's Mac and iPhone), and to the tailnet only as `<tailnet>`.
- R6. 0005's intent names, as part of its end-to-end test, the first live check of what homelab provides: the Pi advertises `svc:liquid-sync`, and its serve config forwards 443 to `127.0.0.1:5984`.
- R7. The stack is unchanged. `compose.yaml` and `deploy/` aren't touched, no Tailscale env file or example is added, and `sdlc verify` passes.
- R8. intent.md records which prerequisites are confirmed and when, the source of the confirmation, and which part waits for 0011 and 0005.

## Design
Docs only. No code, config or secrets change.

- **Publishing model, stated once and referred to elsewhere:** ADR 0001's new "Tailscale publishing" decision bullet is the canonical statement in this repo. The README requirement line and the project plan's component 2 summarize it and point to homelab ADR 0005. Always write "homelab ADR 0005" in full, so it isn't confused with work item 0005 or this repo's ADR numbering.
- **ADR 0001 amendments** (already drafted in the working tree):
  - Context and Production OS: an 8 GB Pi 4, booting from a USB flash drive.
  - Rootless bullet: the sidecar and userspace sentence is removed. "No ports below 1024" still holds, because the host's tailscaled owns 443.
  - New "Tailscale publishing" decision.
  - The compose rule is rewritten: no Tailscale container, key or state volume; CouchDB on `127.0.0.1` only; reached through `svc:liquid-sync` and never Funnel; homelab's policy limits access to 443.
  - The Consequences bullet about proving userspace serve is replaced with a note that the question no longer applies.
  - Evidence: no change. Its `sidecar` is an alpine test container in recorded output.
- **README diagram:** the host box is labelled `host (Pi 4)`, because a Mac signed in as a user can't host a Service.
- **Hand-off to 0005:** add one line to 0005's Proposed outcome (R6). 0005 is a draft intent on main, so the line is an intent edit, not part of this item's diff. The build only checks that the line is there.
- **Rollback:** revert the PR. Nothing outside the docs depends on these edits.

## Acceptance criteria
- AC1 (0010 R1, R2): `git grep -n -i -E 'sidecar|auth key' -- README.md docs/project-plan.md` prints nothing.
- AC2 (0010 R1, R2, R3): `git grep -c 'homelab ADR 0005' -- README.md docs/project-plan.md docs/decisions/0001-container-runtime-and-deployment.md` reports a count of at least 1 for each of the three files.
- AC3 (0010 R3):
  - `grep -n -E 'TS_USERSPACE|/dev/net/tun' docs/decisions/0001-container-runtime-and-deployment.md` prints nothing.
  - `grep -c 'svc:liquid-sync' docs/decisions/0001-container-runtime-and-deployment.md` is at least 3: the decision, the compose rule and the consequence.
  - `git diff main -- docs/decisions/0001-container-runtime-and-deployment.md` shows no changed lines between `### Evidence` and `## Consequences`.
- AC4 (0010 R3, R4): `git grep -n -E 'USB SSD|4 GB Pi' -- README.md docs` prints nothing. `grep -n 'Amended 2026-11-26' docs/decisions/0002-archiver-approach.md` prints one line.
- AC5 (0010 R5): reading `git diff main` shows every host and device named generically, and every tailnet DNS name written as `<tailnet>.ts.net`.
- AC6 (0010 R6): `grep -n 'advertis' work/0005-*/intent.md` prints a Proposed outcome line naming the Pi advertising `svc:liquid-sync` and the serve config forwarding to `127.0.0.1:5984`.
- AC7 (0010 R7):
  - `git diff --stat main -- compose.yaml deploy/` prints nothing.
  - `ls *.env.example` lists only `couchdb.env.example`.
  - `sdlc verify` ends with `verify: PASS`.
- AC8 (0010 R8): intent.md's first open question is marked `[x]`. It is dated 2026-11-26, names homelab's passing policy tests as the source, and names 0011 for the work still to come.

## Open questions
- [x] Is the homelab policy file merged and applied, with its tests passing? — Yes, as of 2026-11-26 (intent.md). homelab's policy is live with its tests passing, the Pi is tagged `tag:server`, and MagicDNS and HTTPS certificates are on.
- [x] How does this repo confirm the prerequisites without being able to read the homelab repo? — deferred: there is nothing to check from this repo until the stack runs on the Pi. The live check (advertise, serve, 443 only) goes into 0005's runbook (R6). A `doctor` check can follow in 0015.

## Standards applied
- `sdlc:security-baseline`:
  - Rule 1: no Tailscale credentials or other secrets are introduced, and the tailnet name stays a placeholder.
  - Rule 5: clients use HTTPS only, through `svc:liquid-sync` on 443.
  - Rule 7: this repo needs no tailnet permission; homelab holds them all.
- CLAUDE.md:
  - Stable endpoint: clients use the Service name, not a machine.
  - No pets: tailnet state is declared in the homelab repo.
  - Don't expose CouchDB publicly: no Funnel, loopback bind.
  - Boring tech: nothing added.
- The owner's public-repo rule: no personal hostnames or devices.
