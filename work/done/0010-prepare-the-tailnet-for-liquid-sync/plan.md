---
id: 0010
title: Tailnet prerequisites provided by homelab ADR 0005
stage: plan
from: spec.md
---
# Plan: Tailnet prerequisites provided by homelab ADR 0005

Docs only. The edits are already drafted and parked in the git stash `0010 docs: homelab ADR 0005 publishing model`, which every worktree of this repo can see. The build applies the stash, checks it against the spec, fixes anything that falls short, and commits. No code, config, compose or quadlet changes.

## Files that change
- `README.md` (edit): the Layout line for `compose.yaml` drops "(+ tailscale sidecar)". The Requirements line says MagicDNS and HTTPS certificates are on, and that the owner's deployment is published as `svc:liquid-sync` by the homelab repo (homelab ADR 0005). The architecture diagram's host box is labelled `host (Pi 4)` (0010 R1).
- `docs/project-plan.md` (edit): component 2 (Tailscale access) and component 9 (Pi deployment); 5.3 host migration; the Phase 1 env-file and HTTPS bullets; first step 4 (0010 R2). Added in review round 1: goal 5 and the Phase 5 migration drill drop the laptop → Pi move (a Mac can't host a Service), and Phase 1 and first step 4 name the Pi deploy (work item 0011) ahead of the HTTPS test (work item 0005).
- `docs/decisions/0001-container-runtime-and-deployment.md` (edit): dated amendments covering the host description, the Rootless bullet, a new "Tailscale publishing" decision, the Tailscale compose rule and the userspace-serve Consequences bullet. Evidence is unchanged (0010 R3).
- `docs/decisions/0002-archiver-approach.md` (edit): the memory-budget context changes to an 8 GB Pi 4, with a dated note that the budget is unchanged (0010 R4).
- `work/done/0010-prepare-the-tailnet-for-liquid-sync/plan.md` (edit): steps ticked during the build.

## Order of work
- [x] 1. Apply the stash in the build worktree.
  - Run `git stash list` to find the entry named `0010 docs: homelab ADR 0005 publishing model`, then `git stash apply stash@{N}` with its index.
  - If it doesn't apply cleanly, resolve the conflicts so that the spec's requirements hold. Only `work/` has changed on main since the stash was made, so a conflict is unlikely.
  - If the stash is missing, write the edits from the spec's Design section instead. Each requirement there is specific enough to do that.
  - Don't drop the stash yet.
- [x] 2. Check the four docs against the spec, and fix any gap in place.
  - Run AC1 to AC4 (see Proof).
  - Read the diff for AC5. Every host and device is named generically (the Pi, the production Pi, the Service host, the owner's Mac and iPhone), and every tailnet DNS name is written as `<tailnet>.ts.net`. Never add a real machine name, device name or tailnet name, not even in a commit message.
  - Check that every amendment in ADR 0001 is dated "2026-11-26", to match homelab ADR 0005's acceptance date and the 0008 amendment style.
  - Check that the README diagram's box edges still line up.
- [x] 3. Run AC6 to AC8 against main's copies of `work/0005-*/intent.md` and `work/0010-*/intent.md`. These are confirmation only: the files were committed on main before this item and aren't part of this diff. Run AC7's `compose.yaml` and `deploy/` diff check, then `sdlc verify`.
- [x] 4. Commit the four docs together with this plan's ticks. Use the subject "Point docs at homelab ADR 0005 for Tailscale publishing", with a body that explains why: the sidecar design is dropped, and the publishing model is now Tailscale Services owned by the homelab repo. Then drop the stash entry with `git stash drop stash@{N}`, using the index from `git stash list`, after confirming it is the 0010 entry.

## Risks
- **Riskiest step: applying the stash (step 1).**
  - It was made on main before `8a4d826` and `271f831`. Those commits touch only `work/`, so the four docs should apply cleanly.
  - The stash is local to this machine. A build on another machine won't find it, and falls back to writing the edits from the spec.
  - Dropping the stash before the commit would lose the drafts, so step 4 drops it only after the commit succeeds.
- **Leaking a personal name.** The edits were drafted from notes that used real host names, and those were removed on 2026-11-26. A fresh build session might reintroduce one from the same notes or from context. Step 2 reads the whole diff for that, and the review pass reads it again.
- **ADR edit versus supersede.** ADR 0001 says that a wrong decision is superseded, not edited. The owner chose amendment with dated notes (spec, Areas of concern). Rejected: writing a new ADR 0003 that supersedes 0001's Tailscale parts. It would split one decision across two files, for what is mostly a deletion.
- **Scope creep.** `CLAUDE.md`'s "Stable endpoint" principle and the runbook also mention Tailscale.
  - The principle still holds as written, because clients point at a stable Tailscale hostname. No edit.
  - 0005 writes the runbook's HTTPS steps.
  - Rejected: editing these here.
- **Overlaps.** `sdlc dep 0010 --check` reports no other open item with a plan touching these files. 0005's intent lists `README.md` as an affected file, but 0005 has no plan yet, and it depends on 0010, so 0010 builds first anyway. No `sdlc dep` change is needed.
- **Rejected: a verify step that lints docs for sidecar wording or private names.** It would be a bespoke script for a one-off change; see the lightweight-tooling preference. The owner also chose no name-list check.

## Proof
- AC1: `git grep -n -i -E 'sidecar|auth key' -- README.md docs/project-plan.md` prints nothing.
- AC2: `git grep -c 'homelab ADR 0005' -- README.md docs/project-plan.md docs/decisions/0001-container-runtime-and-deployment.md` prints three lines, each with a count of 1 or more.
- AC3:
  - `grep -n -E 'TS_USERSPACE|/dev/net/tun' docs/decisions/0001-container-runtime-and-deployment.md` prints nothing.
  - `grep -c 'svc:liquid-sync' docs/decisions/0001-container-runtime-and-deployment.md` prints 3 or more.
  - `git diff main -- docs/decisions/0001-container-runtime-and-deployment.md | grep -n -E '^[-+].*(lssample|lsnet|podlet:v0.3.2 --file)'` prints nothing, so the Evidence section is untouched.
  - Reading the hunks confirms that none falls between `### Evidence` and `## Consequences`.
- AC4: `git grep -n -E 'USB SSD|4 GB Pi' -- README.md docs` prints nothing. `grep -c 'Amended 2026-11-26' docs/decisions/0002-archiver-approach.md` prints 1.
- AC5: read `git diff main`. All hosts and devices are named generically, and tailnet names are written as `<tailnet>.ts.net`.
- AC6: `grep -n 'advertis' work/0005-serve-couchdb-over-https-through-a-tailscale-sid/intent.md` shows the Proposed outcome line about the Pi advertising `svc:liquid-sync` and serve forwarding 443 to `127.0.0.1:5984`.
- AC7:
  - `git diff --stat main -- compose.yaml deploy/` prints nothing.
  - `ls *.env.example` prints only `couchdb.env.example`.
- AC8: `grep -n '\[x\] Is the homelab policy file' work/done/0010-prepare-the-tailnet-for-liquid-sync/intent.md` shows the answer: dated 2026-11-26, citing homelab's passing policy tests, and naming 0011.
- `sdlc verify` ends with `verify: PASS`.

## Parallel tracks
None. It's one small docs change.
