---
id: 0001
title: Block personal and secret leaks before commit and push
type: chore
status: rejected
risk: low
tier: high
priority: P1
author: Mike Garabedian
created: 2026-11-21
branch: work/0001-block-personal-and-secret-leaks-before-commit-an
pr: 
spec_hash: requirements=346e44be5c8b;acceptance-criteria=04e486f56e75;areas-of-concern=eb22907693e1
started: 2026-11-21T16:56:41+00:00
rejected_reason: parked: trying gitleaks in GitHub CI instead; revisit later from branch work/rejected/0001-block-personal-and-secret-leaks-before-commit-an
---
# Intent: Block personal and secret leaks before commit and push

## Problem
This repo is public, and nothing stops a commit or push that contains secrets or personal data. Once pushed, a leak can't be fully taken back: rewritten commits stay reachable on GitHub by SHA (we already hit this with a work email on the initial commit). GitHub push protection only knows provider token formats, not setup URIs, Tailscale names, home network details or author emails.

## Proposed outcome
- A commit whose staged diff contains a leak fails, naming `file:line` and the rule that matched, with the matched value masked so the warning doesn't itself print the secret.
- A push fails if any outgoing commit contains a leak in its content or carries an author/committer email other than an allowed one (the GitHub noreply address).
- `sdlc verify` fails when any tracked file contains a leak, so `sdlc submit` and any future CI enforce it even where hooks aren't enabled.
- A false positive is allowed only by a visible exception, an inline marker on the line (e.g. `leak-check: allow`) or an in-repo allowlist file, so every exception shows up in review.
- Personal patterns (email, tailnet name, real hostnames, home subnet) come from a file outside the repo. If it's missing, the generic patterns still run and a warning says personal patterns weren't checked.
- The pre-commit hook also runs shellcheck on staged shell scripts (plan Phase 2).
- Enabling the hooks in a clone is one documented, idempotent step.

## Affected users and systems
- The repo owner and any AI agent committing here (Claude Code, sdlc's own commits).
- New: the leak-check script, committed git hooks (pre-commit, pre-push), the in-repo generic pattern list and allowlist.
- Changed: `.sdlc/config.toml` (new verify step), contributor docs (README or CLAUDE.md) for enabling hooks and where the personal pattern file lives.

## Constraints
- Bash and grep only, with `set -euo pipefail`, passing shellcheck (CLAUDE.md "boring tech"). No new binaries, so no ADR.
- Must run on macOS (BSD userland) and Linux (GNU userland, Fedora IoT, CI runners).
- Never print a matched secret in full; never write personal patterns into the repo, logs or commit messages.
- The personal pattern file path must not itself reveal personal details when documented.
- Scope per layer: pre-commit scans the staged diff, pre-push scans outgoing commits plus emails, verify scans the tracked tree. Fast enough to not be noticed on commit.
- Generic patterns at least: private IPv4 ranges, `*.ts.net` hostnames, `tskey-` keys, LiveSync setup URIs, credentialed `http(s)://user:pass@` URLs, non-empty secret assignments in `.env`-style lines, non-noreply author emails.

## Out of scope
- Scanning or purging history that's already pushed.
- Replacing GitHub secret scanning or push protection (both stay on).
- Entropy-based or provider-token detection beyond the listed patterns.
- Server-side or CI enforcement beyond the verify step (CI workflows are a separate decision).
- Scanning vault content or CouchDB data (never in the repo by design).

## Open questions
- [ ] Where does the personal pattern file live by default (e.g. `~/.config/liquid-sync/leak-patterns`), and is it overridable by an env var?
- [ ] How does the check exempt its own pattern and test files, which must contain example leaks?
- [ ] How are hooks enabled: `git config core.hooksPath .githooks` by hand, or as part of `./liquid-sync init` once the CLI exists?
- [ ] Should allowed author emails be configurable, or is it just the noreply pattern?

## Tier
high — the verify step lives in .sdlc/config.toml, which sdlc treats as control-plane, and the hooks gate every commit and push.
