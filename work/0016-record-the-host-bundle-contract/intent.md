---
id: 0016
title: Record the host bundle contract
type: chore
status: draft
risk: low
tier: 
priority: P2
author: Mike Garabedian
created: 2026-11-27
branch:
pr:
---
# Intent: Record the host bundle contract

## Problem
The host side has agreed a contract for how a stack is installed on the production host: liquid-sync ships a bundle at a git tag (`deploy/quadlets/` plus optional `deploy/hooks/`), and a host tool, owned outside this repo, installs it. liquid-sync's docs don't record that contract yet. ADR 0001 still says `deploy/` installs the quadlets itself, and 0011 and 0012 now cite a contract ADR that doesn't exist.

## Proposed outcome
- `docs/decisions/0003-host-bundle-contract.md` restates the contract in generic terms ("the host tool"). A draft is in this item's folder, `adr-0003-draft.md`.
- ADR 0001 gets dated amendments:
  - "Nothing in liquid-sync needs root" stands.
  - "`deploy/` can then install and update them without root" becomes: the host tool installs `deploy/quadlets/` and runs `deploy/hooks/`.
  - The service user is provided by the host tool, not this repo.
  - The Consequences bullet ("all declared in `deploy/`") and the compose rule ("the directory `deploy/` installs") are reworded to match.
- `docs/project-plan.md` matches:
  - component rows 3 and 9;
  - §5.3's "provision the new host (`deploy/`)";
  - the Phase 2 init line and the Phase 5 `deploy/` line.

## Affected users and systems
Docs only: `docs/decisions/0001-container-runtime-and-deployment.md`, the new `docs/decisions/0003-host-bundle-contract.md`, `docs/project-plan.md`, and `README.md` if it describes deploying.

## Constraints
- The host-side repo is private. Don't cite its paths, host names, secret store or ADR numbers in what gets committed. Call it "the host tool" or "the host side".
- Amend ADR 0001 in place with dated notes, as 0010 did. Don't rewrite its decision.

## Out of scope
- Any change to `deploy/`, `compose.yaml`, `config/` or scripts (0011, 0012).
- The existing "homelab ADR 0005" citations in ADR 0001, the project plan and 0005's intent. Whether to keep them is the owner's call.

## Open questions

## Tier
small — docs only, three or four files, no code.

## Checks
- `sdlc verify` passes.
- A read of the diff finds no host-side repo paths, host names, secret-store names or ADR numbers that weren't already committed.

## Order of work
- [ ] Add `docs/decisions/0003-host-bundle-contract.md` from `adr-0003-draft.md`.
- [ ] Amend ADR 0001 (dated 2026-11-27, 0016).
- [ ] Update `docs/project-plan.md` (and `README.md` if needed).
- [ ] Run `sdlc verify`.
