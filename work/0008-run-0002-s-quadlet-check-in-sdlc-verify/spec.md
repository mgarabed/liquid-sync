---
id: 0008
title: Run 0002's quadlet check in sdlc verify
stage: spec
from: intent.md
---
# Spec: Run 0002's quadlet check in sdlc verify

## Areas of concern
- [x] **A skipped step still shows as ✓ in verify's summary.** `sdlc verify` has no "skipped" state for a step. It only knows exit codes (`sdlc_cli.py` cmd_verify), so a skip that exits 0 prints `✓ quadlets` and `verify: PASS (shellcheck, quadlets)`. Under `sdlc verify --quiet` the warning line is hidden too, because only failing steps' output is shown. That conflicts with the intent's "a skipped check must not look like a pass". — Proposed resolution: accept it for this repo. The step's own output prints a loud `SKIPPED` line, which is visible in normal verify runs and in the verify log. Capture a follow-up for sdlc-kit (a step exit code or marker that verify reports as "skipped") rather than changing sdlc-kit in this item. — decided: accept it, and capture the follow-up in sdlc-kit.
- [x] **ADR 0001 says it's "superseded by a new ADR, not edited".** Its "Podman compatibility" decision and its Consequences both say 0002 adds the verify step, and the step will now skip without Podman. — Proposed resolution: the decision itself (option A, with a verify check) stands, so this is a factual update rather than a reversal. Add a short dated amendment line under "Podman compatibility" (0008 adds the step, and it skips with a warning when Podman isn't reachable) instead of writing ADR 0002 for it. The Consequences line gets the same correction. — decided: a dated amendment line.
- [x] **Telling "Podman unavailable" apart from "Podman broken"** (carried from the intent). — Proposed resolution: "unavailable" means exactly two things. Either the `podman` binary isn't found (`PODMAN`, or `podman` on PATH), or `podman info` can't reach an engine (the machine is stopped, or there's no connection). Only these skip, and only with the new opt-in flag. Anything after that point (a failed image pull, a podlet error, a diff, a dry-run rejection) fails as it does today, flag or not. A first run while offline therefore fails rather than skips, which is the safe side. — decided: as proposed (the intent asked for the two cases to be told apart).
- [x] **Claude's shell doesn't see `/opt/podman/bin` yet.** It was checked on 2026-11-24 in a new session: PATH has no podman entry, even though `~/.zshrc` line 137 adds it, so `podman` exits 127 there. Agent-run verifies would therefore always take the skip path, and the check would never run where most builds happen. — Proposed resolution: the owner moves the PATH export to `~/.zshenv`, which every zsh reads, interactive or not, outside this repo. The build's AC1 run then proves that the step really executes: `check-quadlets: OK`, not `SKIPPED`. — decided: the step sets `PODMAN` itself. It uses `podman` from PATH when there is one, and otherwise falls back to `/opt/podman/bin/podman` (the macOS `.pkg` location). This overrides the intent's "no hard-coded `/opt/podman` fallback" constraint, by the owner's choice on 2026-11-24. A `PODMAN` already set in the environment still wins. AC1 must show `check-quadlets: OK` from an agent shell.
- [x] **Control-plane edit.** `.sdlc/config.toml` is gated: the edit triggers sdlc's control-edits ask, and the new step counts only once it's merged to main. — Proposed resolution: expected for the high tier. The owner approves that edit when the build reaches it. — decided: the owner approves it during the build.
- [x] Security baseline: no secrets are involved. The script keeps staging `couchdb.env.example` under the real name and never reads `couchdb.env`. There are no new dependencies, permissions or network endpoints, beyond the digest-pinned image pulls the script already does.
- [x] History: 0002 (merged) created `scripts/check-quadlets` and explicitly left `.sdlc/config.toml` to 0008 (its spec, "Not changed"). `.sdlc/config.toml` has no earlier item history. 0002 is merged, so there's no open dependency to record.

## Requirements
- R1: `sdlc verify` and `sdlc verify --fast` both run the quadlet check, after shellcheck. It finds Podman from an agent shell whose PATH lacks `/opt/podman/bin`.
- R2: When the committed quadlets differ from podlet's output for `compose.yaml`, or `quadlet -dryrun -user` rejects them, the verify step fails. Its output names the difference and says to run `scripts/check-quadlets --write`.
- R3: When Podman is unavailable (no `podman` binary found, or no reachable engine), the verify step exits 0 and prints a line containing `SKIPPED` that says the quadlet check didn't run, and why.
- R4: When Podman is reachable, every failure (image pull, podlet, diff, dry-run) fails the step, even in skip mode.
- R5: Run by hand without the new flag, `scripts/check-quadlets` keeps failing when Podman is unavailable, now with a message that says whether the binary is missing or the engine is unreachable.
- R6: `--help` documents the new flag. The script still passes `shellcheck -x` and never reads a real secret.
- R7: ADR 0001's "Podman compatibility" text and its Consequences line match the behaviour: 0008 adds the step, and the step skips with a warning when Podman is unavailable.

## Design
- **`scripts/check-quadlets`:**
  - Add a `--skip-if-no-podman` flag, parsed alongside `--write`.
  - Replace the bare `command -v` check with an availability check that runs before any staging:
    1. Resolve `PODMAN` (default `podman`) with `command -v`. If nothing is found, the reason is "podman not found".
    2. Run `"$PODMAN" info >/dev/null 2>&1`. If that fails, the reason is "podman can't reach an engine (machine stopped?)".
    3. If either fails: with `--skip-if-no-podman`, print `check-quadlets: SKIPPED — <reason>; the quadlet check did not run` to stderr and exit 0. Without the flag, `die` with the reason, as today.
  - Everything after the check is unchanged, so R4 holds by construction.
  - `--write` with `--skip-if-no-podman` is allowed. It skips the same way, since writing needs Podman too.
- **`.sdlc/config.toml`:** add one step after shellcheck, with no `fast` key, so both profiles run the same command:
  `{ name = "quadlets", run = "PODMAN=\"${PODMAN:-$(command -v podman || echo /opt/podman/bin/podman)}\" scripts/check-quadlets --skip-if-no-podman" }`
  The step runs under `/bin/sh`. An exported `PODMAN` wins, then `podman` on PATH (Linux, or a Mac whose shell has it), then the macOS `.pkg` path. On a host with none of those, the script finds no binary and skips (R3). The fallback lives in the verify step, so running the script by hand stays PATH-only.
- **ADR 0001:** the amendment line under "Podman compatibility" (a dated `Amended 2026-11-24 (0008): …`) and a corrected Consequences bullet. No other text changes.
- **Rollback:** revert the commit. The step disappears from verify, and the script's default behaviour is the same as before, apart from the clearer error message.
- Not changed: what the check validates, the pinned image digests, `compose.yaml` and `deploy/quadlets/`.

## Acceptance criteria
- AC1 (R1): run from Claude's shell, where PATH has no podman, `sdlc verify` output contains a `── quadlets:` line, then `check-quadlets: OK` (not `SKIPPED`), and ends with `verify: PASS (shellcheck, quadlets)`. `sdlc verify --fast` shows the same step and ends with `verify: PASS [fast] (shellcheck, quadlets)`.
- AC2 (R2, R4): in a scratch copy of the repo (outside the working tree), changing `mem_limit` in `compose.yaml` makes `scripts/check-quadlets --skip-if-no-podman` exit non-zero, name the differing file, and print the `--write` hint. Corrupting a key in a committed quadlet in the scratch copy makes it exit non-zero with `quadlet -dryrun -user rejected`.
- AC3 (R3): `PODMAN=/nonexistent/podman scripts/check-quadlets --skip-if-no-podman` exits 0 and prints a `SKIPPED` line that says "not found". `CONTAINER_HOST=unix:///nonexistent.sock scripts/check-quadlets --skip-if-no-podman` (engine unreachable) exits 0 and prints a `SKIPPED` line that says it can't reach an engine.
- AC4 (R5): the two commands from AC3, without `--skip-if-no-podman`, each exit non-zero with the matching reason.
- AC5 (R6): `scripts/check-quadlets --help` mentions `--skip-if-no-podman`. `shellcheck -x scripts/check-quadlets` exits 0. `grep -n 'couchdb.env' scripts/check-quadlets` shows only the `couchdb.env.example` staging line.
- AC6 (R7): `grep -n '0008' docs/decisions/0001-container-runtime-and-deployment.md` shows the amendment under "Podman compatibility" and the corrected Consequences bullet. Neither of them still says that 0002 adds the step.
- AC7: a full `sdlc verify` ends with `verify: PASS`.

## Open questions
- [x] Should the skip be distinguishable from "Podman present but broken"? — answered: yes. Only a missing binary or an unreachable engine skips; see Areas of concern and R4.
- [x] Does the skip belong in `scripts/check-quadlets` or in the verify step's command? — answered: in the script, behind an opt-in `--skip-if-no-podman` flag. That keeps the availability logic in one tested, shellchecked place, and running the script by hand stays strict.

## Standards applied
- sdlc:security-baseline (secrets: the example env file only; fail closed: a skip only for a clearly identified absence of Podman, never for a failure)
- CLAUDE.md (bash with `set -euo pipefail`, shellcheck, `--help`, and requirement references)
- ADR 0001 (the compose and quadlet check, and the rule that ADRs are amended or superseded rather than rewritten)
