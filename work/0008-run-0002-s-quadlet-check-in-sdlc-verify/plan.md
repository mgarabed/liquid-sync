---
id: 0008
title: Run 0002's quadlet check in sdlc verify
stage: plan
from: spec.md
---
# Plan: Run 0002's quadlet check in sdlc verify

## Files that change
- `scripts/check-quadlets` (edit) — add the `--skip-if-no-podman` flag and a Podman availability check (binary found, engine reachable) that runs before any staging (0008 R3–R6).
- `docs/decisions/0001-container-runtime-and-deployment.md` (edit) — a dated amendment under "Podman compatibility" and a corrected Consequences bullet (0008 R7).
- `.sdlc/config.toml` (edit) — add the `quadlets` verify step after shellcheck (0008 R1). This is a control-plane file, so the owner approves the edit.
- `work/0008-run-0002-s-quadlet-check-in-sdlc-verify/plan.md` (edit) — tick steps and record the proof results.

## Order of work
- [x] 1. **Script: the availability check and the flag.** In `scripts/check-quadlets`:
  - Parse `--skip-if-no-podman` in the existing `for arg` loop, setting `skip_if_no_podman=1`. Document it in `usage()`: "exit 0 with a SKIPPED warning when Podman isn't installed or can't reach an engine; every other failure still fails".
  - Replace the `command -v "$PODMAN" … || die …` line with a function, `podman_unavailable_reason`. It prints a reason and returns 0 when Podman is unavailable, and returns 1 otherwise:
    - binary: `command -v "$PODMAN" >/dev/null 2>&1`, or the reason is `podman not found ('$PODMAN'); set PODMAN or add it to PATH`
    - engine: `"$PODMAN" info >/dev/null 2>&1`, or the reason is `podman ('$PODMAN') can't reach an engine (is the Podman machine running?)`
  - If there's a reason: with the flag, `echo "check-quadlets: SKIPPED — $reason; the quadlet check did not run" >&2; exit 0`; without it, `die "$reason"`.
  - Keep this before `root=`, `mktemp` and the trap, so a skip creates nothing. Nothing after it changes.
  - Run `shellcheck -x scripts/check-quadlets`, then AC3, AC4 and AC5 (see Proof), and the AC2 scratch-copy checks. Commit: `0008: skip check-quadlets cleanly when Podman is unavailable`.
- [x] 2. **ADR 0001 amendment.** Under the "Podman compatibility" bullet, add an indented line: `Amended 2026-11-24 (0008): the step is added by 0008, not 0002. It runs scripts/check-quadlets --skip-if-no-podman, which exits 0 with a SKIPPED warning only when no podman binary is found or it can't reach an engine; any other failure fails verify.` In Consequences, change "0002 writes `compose.yaml` to the compose rules and adds the verify step (…)" to say that 0002 writes `compose.yaml` and the check script, and 0008 adds the verify step. Change no other text. Run AC6. Commit: `0008: amend ADR 0001 for the verify step's Podman skip`.
- [x] 3. **Verify step (control-plane edit; the owner approves).** In `.sdlc/config.toml` `[verify] steps`, add after the shellcheck entry:
  `{ name = "quadlets", run = "PODMAN=\"${PODMAN:-$(command -v podman || echo /opt/podman/bin/podman)}\" scripts/check-quadlets --skip-if-no-podman" },`
  Don't add a `fast` key, so `--fast` runs the same command. Run AC1 from Claude's shell (no podman on PATH), then the PATH-podman case. Commit: `0008: run the quadlet check in sdlc verify`.
- [ ] 4. **Record the proof.** Paste the AC results and the `sdlc verify` summary line into this plan's Proof section, tick the steps, and commit.

## Risks
- **Riskiest step: 3, the config edit.** A TOML quoting mistake, or a `/bin/sh` expansion mistake in `run`, would break every verify, not just this step. The mitigation is to run `sdlc verify` straight after the edit. Each step's run string is hashed into verify's state, so earlier passes stop counting, which is expected.
- **A false skip.** If `podman info` fails for a reason other than "no engine" (a corrupt rootless config on Linux, say), the step skips instead of failing. That's accepted in the spec: the SKIPPED line includes the reason, and running the script by hand without the flag still fails. Showing `podman info`'s own stderr was considered and rejected, because it would be noisy on every skip on a docker-only machine.
- **`podman info` is slow when the machine is stopped.** The Mac remote client may wait on the connection before it fails. Measure this during step 1 (AC3b uses a bogus socket, which fails fast). If a real stopped machine takes more than about 10s, note it here instead of adding a timeout: macOS has no `timeout` without coreutils, and installing it needs the owner's OK.
- **The fallback path on Linux.** On a Linux host without podman, the step passes `/opt/podman/bin/podman`, which doesn't exist, so the script reports "not found" and skips. That's correct.
- **A skip still shows ✓.** Accepted in the spec. The sdlc-kit follow-up for a real skipped state is tracked outside this repo.
- **Rejected:** a test script under `test/` for the skip cases. The ACs are short commands, and this repo has no shell test harness yet. Adding one is a separate decision.
- **History:** 0002 created `scripts/check-quadlets` and left the verify wiring to this item. 0006 wrote ADR 0001. `sdlc dep 0008 --check` reports no overlapping open plans: 0005, 0007 and 0009 have no plans yet. 0005 will edit `compose.yaml` and regenerate the quadlets, so building 0008 first means 0005 gets checked.

## Proof
- AC1 (0008 R1): from Claude's shell (`command -v podman` is empty), run `sdlc verify`. Expect `── quadlets: PODMAN=…`, then `check-quadlets: OK`, then `verify: PASS (shellcheck, quadlets)`. Run `sdlc verify --fast` and expect `verify: PASS (shellcheck, quadlets)` (no `[fast]` label: this repo has no `fast` commands, so `--fast` is a full run). Then `PATH="/opt/podman/bin:$PATH" sdlc verify --fast`, which also shows `check-quadlets: OK`.
- AC2 (0008 R2, R4): `d=$(mktemp -d "$TMPDIR/q.XXXXXX") && git archive HEAD | tar -x -C "$d"`.
  - Run `sed -i '' 's/mem_limit: 512m/mem_limit: 256m/' "$d/compose.yaml"`, then `PODMAN=/opt/podman/bin/podman "$d/scripts/check-quadlets" --skip-if-no-podman`. Expect a non-zero exit, a diff naming `couchdb.container`, and the `--write` hint.
  - Restore the line, run `sed -i '' 's/^\[Container\]$/[Container]\nBogusKey=1/' "$d/deploy/quadlets/couchdb.container"`, and rerun. Expect a non-zero exit and `quadlet -dryrun -user rejected`. (The key goes in `[Container]`: an unknown key appended at the end lands in `[Install]`, which quadlet doesn't validate, so only the diff would fail.)
  - Afterwards, `podman` cleanup isn't needed (the containers use `--rm`), and the scratch dir is left for the OS to clear.
- AC3 (0008 R3): `PODMAN=/nonexistent/podman scripts/check-quadlets --skip-if-no-podman; echo rc=$?` gives `SKIPPED — podman not found` and `rc=0`. `CONTAINER_HOST=unix:///nonexistent.sock PODMAN=/opt/podman/bin/podman scripts/check-quadlets --skip-if-no-podman; echo rc=$?` gives `SKIPPED — … can't reach an engine` and `rc=0`.
- AC4 (0008 R5): the same two commands without the flag give `rc=1` with the matching reason.
- AC5 (0008 R6): `scripts/check-quadlets --help | grep -- --skip-if-no-podman`. `shellcheck -x scripts/check-quadlets` exits 0. `grep -n 'couchdb.env' scripts/check-quadlets` matches only the `couchdb.env.example` staging line (and comments).
- AC6 (0008 R7): `grep -n '0008' docs/decisions/0001-container-runtime-and-deployment.md` shows the amendment and the Consequences bullet. `grep -n '0002 adds' …` finds only the original "Podman compatibility" sentence on line 84, which stays as the ADR's record and is corrected by the amendment beneath it.
- AC7: a full `sdlc verify` ends with `verify: PASS`. Paste the summary line here.
- **Rollback:** `git revert` the merge commit on main. The `quadlets` step leaves verify, the ADR text returns to before, and the script goes back to its old behaviour. Nothing outside the repo changes (no hosts, data or images), so there's nothing else to undo.

## Parallel tracks
<!-- None: three small sequential edits; step 3 depends on step 1's flag existing. -->
