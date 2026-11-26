---
id: 0007
title: "Spike A: choose the archiver approach (ADR 0002)"
stage: spec
from: intent.md
---
# Spec: Spike A: choose the archiver approach (ADR 0002)

## Areas of concern
- [ ] **How far to evaluate.** The project plan (Phase 3, first step 5) says to evaluate (b) → (a) → (c) in order, which reads as "stop at the first one that works". The intent adds (d), Differential ZIP Backup. — Proposed resolution: evaluate all four against the same criteria, with less depth for an option once a hard constraint rules it out (for example, it can't run server-side, or there's no arm64 build). Record where and why each one stopped. A ruled-out option still gets its row in the comparison table, so the ADR shows it was considered.
- [ ] **The answer may come in two parts.** The intent's own (d) roles include "a separate client-side disaster-recovery backup". A good outcome could be "archiver X for git history, plus Differential ZIP Backup as an independent backup", but backup is Phase 5's area. — Proposed resolution: ADR 0002 decides the archiver (D1) and D2. If it recommends Differential ZIP Backup as a complementary backup, it states that as a recommendation for Phase 5's `backup` item, not a decision, and records it under Consequences.
- [x] **Research-only evidence is weaker than measured evidence** (the owner chose research only). Memory use, storage-format behaviour and arm64 support can only be read from docs and source, not observed. — Resolution: every factual claim in the ADR cites a source URL and the date it was read, labelled "documented", "read in source" or "inferred". Anything inferred that the decision rests on becomes an explicit gate for the Phase 3 implementation item (as the intent already does for headless Obsidian's memory).
- [x] **A new language or runtime is likely.** Option (b) candidates and option (c) may need something other than bash (a JS/TS runtime, for instance), which CLAUDE.md's "boring tech" rule allows only with an ADR. — Resolution: ADR 0002 is that ADR. It has a short "Runtime" section naming any runtime the chosen option brings, why bash can't do the job, and the image it would run in (multi-arch, pinned per CLAUDE.md).
- [x] **Licences and third-party code.** The repo is MIT. A candidate under GPL or AGPL is fine to run as a separate unmodified container, but not to vendor into this repo. — Resolution: the comparison records each candidate's licence and how liquid-sync would consume it (a pulled image, a pinned release, or vendored), and flags any conflict with MIT.
- [x] **Plugin-version coupling.** (b) and (c) read LiveSync's internal storage format, and (a) and (d) run the plugin itself. All of them tie the archiver to the LiveSync version on clients. — Resolution: the ADR states how the chosen option is pinned, and how a LiveSync upgrade is detected and tested on the fixture vault before clients upgrade (plan §5.3). That becomes a requirement for Phase 3.
- [x] **Security baseline.** This item runs no code and stores no secrets. The ADR's D2 section must say where a passphrase would live (a git-ignored per-service `*.env`, never in git or logs, per CLAUDE.md) and what an attacker who reaches the host or its backups gains under each option. Following baseline rule 6, any dependency the chosen option brings is justified in the ADR (maintenance, licence, size).
- [x] **History.** No earlier item touched the archiver. 0006 wrote ADR 0001, whose format (Context, Options, Decision, Evidence, Consequences) and 1 GB memory budget this ADR follows. 0003 confirmed LiveSync 1.0.52 works against this CouchDB setup, which is the version the research targets. No open dependency to record.

## Requirements
- R1: ADR 0002 exists at `docs/decisions/0002-archiver-approach.md`, in ADR 0001's format (Status, Date, Work item; Context; Options; Decision; Evidence; Consequences).
- R2: It compares options (a), (b), (c) and (d) on the same criteria: runs server-side without a client; output meets goal 2 (plain Markdown in git, browsable); handles E2EE and path obfuscation; arm64 and amd64 container; rootless and podlet-expressible; expected memory against the 1 GB budget; maintenance (last release, release cadence, maintainer, open issues); licence; how it's pinned; and the cost of a LiveSync version change.
- R3: Every factual claim cites a source URL and the date it was read, and is labelled documented, read in source, or inferred.
- R4: It picks exactly one archiver approach (D1), and states why each other option wasn't chosen.
- R5: It decides D2, with the threat each option leaves (host compromise, backup theft), where any passphrase is stored, and the recommendation.
- R6: It says whether the choice brings a new language or runtime, and if so, justifies it and names the pinned multi-arch image.
- R7: It lists the gates the Phase 3 implementation item must pass: the round-trip test on the fixture vault with E2EE on, a memory measurement on the Pi, LiveSync version pinning and the upgrade check, and anything inferred the decision rests on.
- R8: It places Differential ZIP Backup in exactly one role (the archiver, inside option (a), a recommended Phase 5 backup, or not used), with the reason.
- R9: `docs/project-plan.md` D1 and D2 are marked resolved with links to ADR 0002, and Phase 3's Spike A bullet points to it.

## Design
- **Research sources,** read only (no candidate code is cloned or run):
  - the LiveSync repo and README, its docs folder and release notes
  - LiveSync ecosystem bridge and CLI repos linked from those docs (each candidate's README, recent releases and issues)
  - headless Obsidian images (for example linuxserver/obsidian: image manifests for arm64, and the documented memory footprint)
  - LiveSync's storage-format source (chunking, E2EE, path obfuscation), for option (c)
  - the diffzip README and source, for option (d)
- **ADR 0002 layout:**
  - Context: goal 2, D1 and D2, ADR 0001's constraints, small vaults, LiveSync 1.0.52.
  - Options: one subsection each for (a)–(d), giving costs and what's given up, as in ADR 0001.
  - A comparison table across R2's criteria.
  - Decision: D1, D2 and the runtime.
  - Evidence: cited claims with labels and dates.
  - Consequences: the Phase 3 gates (R7), the Phase 5 recommendation if any (R8), and when to revisit.
  - Status is `proposed` on the branch and `accepted` in the merge commit, matching how ADR 0001 landed.
- **Project plan edits:** D1 and D2 get `_Resolved:_ … See [ADR 0002](decisions/0002-archiver-approach.md).`, like D3. The Phase 3 Spike A bullet links to the ADR. No other plan text changes. If the ADR picks a design that contradicts component 4's description ("Follows each vault database's `_changes` feed …"), that row is updated to match.
- Nothing else changes: no compose, quadlet, script or config edits.

## Acceptance criteria
- AC1 (R1): `test -f docs/decisions/0002-archiver-approach.md`, and `grep -c '^## \(Context\|Options\|Decision\|Consequences\)' …` returns 4. `grep -n '^### Evidence\|^## Evidence'` matches.
- AC2 (R2, R4): the Options section has a subsection for each of (a)–(d). The comparison table has one row per option and a column per R2 criterion. The Decision section names exactly one option for D1, and each other option has a "not chosen because" line. Checked by reading the ADR, and by `grep -c 'not chosen because'` returning 3.
- AC3 (R3): every link in Evidence has a read date (`grep -E '\]\(https?://' … | grep -vc '20[0-9]{2}-[0-9]{2}-[0-9]{2}'` returns 0 within the Evidence section). Each claim carries one of the labels `documented`, `read in source` or `inferred`.
- AC4 (R5): the Decision section has a D2 paragraph that names where the passphrase lives (or why there isn't one), and a sentence for each of host compromise and backup theft.
- AC5 (R6): a "Runtime" heading or paragraph exists. If a new runtime is chosen, it names a pinned multi-arch image tag, not `latest`.
- AC6 (R7): Consequences lists the Phase 3 gates, including the round-trip test with E2EE on, the memory measurement on the Pi, and the LiveSync upgrade check.
- AC7 (R8): `grep -n -i 'differential zip\|diffzip'` in the Decision or Consequences section shows exactly one assigned role.
- AC8 (R9): `grep -n 'ADR 0002\|0002-archiver-approach' docs/project-plan.md` matches in D1, D2 and Phase 3.
- AC9: `sdlc verify` ends with `verify: PASS`.

## Open questions
- [x] Is there a maintained LiveSync file bridge or CLI today (option b)? Who maintains it, and does it track plugin releases? — deferred: that's the research itself. The answer lands in ADR 0002's Options and Evidence (R2, R3).
- [x] How stable is LiveSync's storage format across plugin versions, and what does a version change cost (b) and (c)? — deferred: research. It's an R2 criterion, and it feeds the Phase 3 upgrade gate (R7).
- [x] Where does Differential ZIP Backup fit? — deferred: research. R8 requires the ADR to give it exactly one role, and Areas of concern says how a backup role is recorded.
- [x] D2: hold the passphrase on the server, keep E2EE off, or archive somewhere else? — deferred: the owner said the spike decides. R5 requires the threat comparison and a recommendation.

## Standards applied
- sdlc:security-baseline (secrets location for D2, dependency justification under rule 6, fail closed)
- CLAUDE.md ("boring tech" and runtime ADRs, multi-arch pinned images, no pets, clients are sacred, ADRs in `docs/decisions/`)
- ADR 0001 (ADR format, 1 GB memory budget, podlet and rootless constraints)
