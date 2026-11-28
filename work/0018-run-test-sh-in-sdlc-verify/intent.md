---
id: 0018
title: Run test/*.sh in sdlc verify
type: chore
status: planned
risk: low
tier: high
priority: P2
author: Mike Garabedian
created: 2026-11-27
branch: 
pr: 
source: 0012
spec_hash: requirements=2ff8f1f2bc74;acceptance-criteria=17412d533ea1;areas-of-concern=8f962321a56b
---
# Intent: Run test/*.sh in sdlc verify

## Problem
Script tests (0011's test-check-quadlets aside) can't join sdlc verify without a .sdlc/config.toml edit, which forces the high tier each time; add one generic verify step that runs every executable test/*.sh so later items add tests without touching control files.

Today `test/liquid-sync-init.sh` (0012) exists, but nothing runs it: it was run by hand for 0012's PR. A regression in `./liquid-sync init` or `scripts/check-couchdb-config` would pass `sdlc verify`.

## Proposed outcome
- `sdlc verify` (full, and `--fast` if the step is quick enough) has one step that runs every `test/*.sh`, and fails if any of them fails, naming the failing file.
- A `test/*.sh` that isn't executable fails the step with its name, so a forgotten `chmod +x` can't hide a test.
- `test/liquid-sync-init.sh` runs in verify from this item on.
- A later item adds a test by dropping an executable `test/<name>.sh` in place: no control-file edit, so no forced high tier.
- The convention is written down where contributors look (README or CLAUDE.md Testing section).

## Affected users and systems
- `.sdlc/config.toml` `[verify] steps`: one new step.
- `test/`: the home for script tests; `test/fixtures/` is not a test and must not be run.
- `test/liquid-sync-init.sh`: the first test the step runs.
- Docs: CLAUDE.md's Testing section and/or the README.

## Constraints
- Tests must stay safe to run on the dev Mac at any time: no real `couchdb.env`, no real vault, no change to the running stack. Today's test meets this (stub podman, closed port, own temp dir).
- Works on macOS and Linux (bash, BSD and GNU tools), like the existing verify steps.
- No new tools or dependencies; the step is a shell one-liner or a small script, in line with "prefer lightweight tooling".
- Editing `.sdlc/config.toml` is a control-file change, so this item is high tier.

## Out of scope
- Moving `scripts/test-check-quadlets` under `test/`. It already runs in verify through the `quadlets` step.
- Remote CI. The repo has no `.github/workflows`; that is a separate item if wanted.
- A test framework (bats or similar).
- Tests in subdirectories of `test/`.

## Open questions
- [ ] Does the step run in `--fast` too? `test/liquid-sync-init.sh` takes about 5 s today, mostly its timeout case.
- [ ] Inline the loop in `config.toml`, or put it in a small runner script (e.g. `scripts/run-tests`)? A script keeps the control file stable if the runner later changes, but is itself one more file.
- [ ] Run the tests in sequence, stopping at the first failure, or run them all and report every failure?

## Tier
high — edits `.sdlc/config.toml`, a control file, which the tier check always counts as high.
