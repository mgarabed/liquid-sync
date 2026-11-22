---
id: 0004
title: Add sample vault test fixture
type: chore
status: in-review
risk: low
tier: small
priority: P2
author: Mike Garabedian
created: 2026-11-21
branch: work/0004-add-sample-vault-test-fixture
pr: 4
depends: 
started: 2026-11-22T18:36:00+00:00
submitted: 2026-11-22T18:40:00+00:00
submitted_verify: full
---
# Intent: Add sample vault test fixture

## Problem
Testing must never touch a real vault. We need `test/fixtures/sample-vault/`, holding a few notes, an image and nested folders, for manual sync tests now and round-trip tests later (project plan, first step 3; CLAUDE.md's Testing rules). No test vault exists yet, so 0003 (syncing a Mac test vault over localhost) and the Phase 3 round-trip test have nothing safe to run against.

## Proposed outcome
- A committed sample vault that works as a fixture: small, original, and meaningful for sync and round-trip tests. It covers:
  - **Awkward file names:** spaces, non-ASCII and emoji names, and folders nested several levels deep.
  - **Obsidian syntax:** frontmatter, `[[wikilinks]]`, `![[embeds]]`, tags, callouts and code blocks, all of which must survive a round trip byte for byte.
  - **Binary attachments:** a small PNG and a small PDF.
  - **A minimal `.obsidian/`:** `app.json` and one CSS snippet, enough to test hidden-file sync later. No plugins and no plugin binaries.
- A copy-out script puts a fresh copy of the fixture in a throwaway folder outside the repo, and prints where. That copy is what gets opened in Obsidian or fed to tests. The committed fixture is never opened, so Obsidian and LiveSync never write into it.
- A short README in the fixture says what each file exercises and states the "never open in place" rule.

## Affected users and systems
- The owner, for manual sync tests (0003, 0005).
- The Phase 3 round-trip test (vault → LiveSync → CouchDB → archiver → files → diff).
- New: `test/fixtures/sample-vault/` and a copy-out script.

## Constraints
- **The repo is public.** All content is original filler: no personal notes, names or homelab details, and no copyrighted images or text.
- **Small files only.** The fixture stays small, and large-attachment and chunking tests are left to later items.
- **The scripts follow CLAUDE.md:** bash with `set -euo pipefail`, passing shellcheck, idempotent, with `--help`.
- **The copy-out target is outside the repo,** so nothing Obsidian writes can be committed by accident.

## Out of scope
- Large or multi-MB files, and chunking or mobile-exclusion tests.
- Empty files, files without a trailing newline, and CRLF line endings.
- Obsidian plugins (LiveSync itself included) inside the fixture's `.obsidian/`.
- The round-trip test itself (Phase 3) and syncing the fixture (0003).
- A second fixture vault for multi-vault tests.

## Open questions
- [x] Case and Unicode normalization: should the fixture avoid case-only name differences and pin NFC? — proposed: yes. There are no names differing only by case (they can't coexist on a default macOS checkout), and every non-ASCII name is committed in NFC. A check confirms the committed names are NFC. The NFD-on-disk round trip is the Phase 3 test's concern.
- [x] Copy-out location? — proposed: a fresh `mktemp -d` by default, printed on stdout. `--to DIR` gives a stable path for Obsidian. The script refuses any target inside the repo, and only replaces a target that holds its own marker file, so it never deletes a folder it didn't create.
- [x] Where the script lives? — proposed: `scripts/fixture-vault`, beside `check-quadlets`.

## Tier
small — fixture files plus one script, with no sensitive or control-plane paths

## Checks
- `scripts/fixture-vault --help` exits 0. `scripts/fixture-vault` prints a directory outside the repo, and `diff -r test/fixtures/sample-vault <that dir>` shows only the marker file.
- `scripts/fixture-vault --to "$(git rev-parse --show-toplevel)/x"` exits non-zero without writing. A second run with `--to` on a stable path replaces the copy, and a `--to` folder without the marker is refused.
- The fixture contains at least one of each: a name with a space, a non-ASCII name, an emoji name, a folder nested at least 3 deep, frontmatter, a `[[wikilink]]`, an `![[embed]]` of the PNG, a tag, a callout, a code block, a `.png`, a `.pdf`, and `.obsidian/app.json` plus `.obsidian/snippets/*.css`.
- Every committed file name is NFC: `git ls-files -z test/fixtures | python3 -c 'import sys,unicodedata as u; n=[p for p in sys.stdin.buffer.read().decode().split("\0") if p and u.normalize("NFC",p)!=p]; print(n); sys.exit(bool(n))'` exits 0. `git ls-files test/fixtures | tr A-Z a-z | sort | uniq -d` is empty.
- `du -sk test/fixtures/sample-vault` is under 200, and no committed file is over 100 KB.
- `git ls-files test/fixtures | grep -E 'workspace|plugins/'` is empty.
- `sdlc verify` prints `verify: PASS`, and its shellcheck step covers `scripts/fixture-vault`.

## Order of work
- [x] 1. Write the notes (original filler) covering the syntax and naming cases, and the fixture `README.md` mapping each file to what it exercises.
- [x] 2. Add a small PNG and a small PDF, both generated or authored here (no third-party content), embedded or linked from a note. Add `.obsidian/app.json` and one CSS snippet.
- [x] 3. Write `scripts/fixture-vault`: bash with `set -euo pipefail`, `--help`, `--to DIR`, a refusal of in-repo targets, and marker-file replace semantics.
- [x] 4. Run the Checks and `sdlc verify`.
