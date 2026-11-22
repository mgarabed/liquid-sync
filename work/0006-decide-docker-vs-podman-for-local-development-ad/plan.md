---
id: 0006
title: Choose the container runtime and deployment model (ADR 0001)
stage: plan
from: spec.md
---
# Plan: Choose the container runtime and deployment model (ADR 0001)

## Files that change
- `docs/decisions/0001-container-runtime-and-deployment.md` (new): the ADR. It's the first one in the repo and sets the format.
- `docs/project-plan.md` (edit): only D3, component 9, Phase 5 and the open-questions list (spec R9). The `deploy/pi/` path name stays as it is. Only its description changes, so section 5.3's mention of it needs no edit.

Evidence files (sample compose, podlet output) live in the session scratchpad, not the repo. Their content is quoted in the ADR's Evidence block.

## Order of work
- [x] 1. **Install Podman, with the owner's approval.** Ask first, and propose `brew install podman`. Don't install Podman Desktop or `podman-mac-helper`. Before installing, record `docker context show` (expected: `colima`). Then:
  - `podman machine init --cpus 2 --memory 2048`, then `podman machine start`
  - confirm `podman info` works, and that `docker context show` still prints `colima` and `docker ps` still lists only Colima's containers

  If the owner declines, the evidence steps below use `docker` on Colima instead, and the ADR says so (spec Design).

  *As done:* the owner installed Podman 6.1.4 with the official `.pkg` installer and Podman Desktop (podman.io recommends the installer over brew), not `brew install podman`. The installer set up `podman-mac-helper`, which linked `/var/run/docker.sock` to the Podman machine once it started. The owner removed it with `sudo /opt/podman/bin/podman-mac-helper uninstall`, which also removed the symlink. Podman Desktop's Docker compatibility setting is off. The machine (`podman-machine-default`, libkrun, rootful, 4 CPUs, ~2 GiB) was created from Podman Desktop. Afterwards: `docker context show` → `colima`, `docker ps` lists only Colima's containers, and `/var/run/docker.sock` doesn't exist.
- [x] 2. **Gather the evidence** in the scratchpad, using pinned image tags only:
  - Write a sample `compose.yaml` using only features the draft compose rules allow:
    - `docker.io/library/couchdb:3.5` on `127.0.0.1:15984:5984` (15984 is free; 5984 is avoided so nothing collides with a later real stack)
    - a small sidecar, `docker.io/library/alpine:<pinned>` with a sleep command
    - a named volume
    - an `env_file:` holding fake values
  - Check `lsof -nP -iTCP:15984 -sTCP:LISTEN` is empty first.
  - **Local run:** `podman compose up -d`. On this Mac it delegates to the installed `docker-compose` binary, and the spec requires checking where the containers land. Capture `podman ps` (both containers listed) and `docker ps` (neither listed), then `podman compose down -v`.
  - **Conversion:** get podlet's container image name and tag from its README, then run `podman run --rm -v <dir>:/w:Z -w /w <podlet image> compose --pod compose.yaml`. Save the `.container`, `.pod` and `.volume` output.
  - **Validation:** dry-run the output with Podman's quadlet generator inside a pinned `quay.io/podman/stable:<tag>` (e.g. `QUADLET_UNIT_DIRS=/q /usr/libexec/podman/quadlet -dryrun` with the output mounted at `/q`). Capture the exit status and the generated unit names.
  - If podlet rejects a feature the rules allow, tighten the rules and rerun. If the image or the dry-run path doesn't work at all, stop and report back; don't switch options (spec Design).

  *Review round 1 fix:* `--pod` is dropped, because the bare service name doesn't resolve inside a quadlet pod. The rules now require `container_name:` on one named network and the `io.containers.autoupdate` label, and the quadlets, env file and config go in the service user's `~/.config/containers/systemd/`, since quadlet resolves relative paths against the unit directory. A second sample proves name resolution under both quadlet and `podman compose`.
  *Rootless check:* the owner reversed the rootful decision during build (see spec). The same podlet output also passes `quadlet -dryrun -user` (exit 0, three services).
  *As done:* the sample also bind-mounts a `./conf` directory with `:ro,Z` and sets `mem_limit:`, and its `env_file:` is named `couchdb-vars.txt` (the session's secrets guard blocks `*.env` names). `:Z` works on the Podman machine's macOS mounts. The negative checks behind the compose rules were also run: podlet exits 1 on `${VAR}` (even with the variable set), on `deploy:` and on `profiles:`, so memory limits use `mem_limit:`. A deliberately broken `.container` makes the quadlet dry-run exit 1, which shows the dry-run really validates.
- [x] 3. **Write the ADR**, about a page and a half:
  - `Status: accepted` and the date
  - **Context:** Pi 4, a shared homelab host, the Mac running Colima for other projects, and CLAUDE.md's compose rule
  - **Options:** A, B and C, each with its cost and what it gives up, linked to sources
  - **Decision:** labelled bullets for all 9 R2 topics: production OS, Colima coexistence, rootless (spec revised during build), the shared host and homelab split, source of truth, local runtime, how Podman is proven, compose rules, memory budget
  - **Compose rules** checklist (`- [ ]` items): fully qualified image names; pinned multi-arch tags; `:Z` on bind mounts; `env_file:` and no `${VAR}`; no `include`, `build`, `deploy`, `profiles`, `extends` or `scale`; host ports on 127.0.0.1; memory limits summing to 1 GB or less
  - **Local development** rules (R10)
  - the **podlet** justification (R7): what it does, maintenance and licence (checked from its repo), container-only use, and the fall-back if it's abandoned (the committed quadlets stay valid and become hand-maintained, which is option C)
  - **Evidence** block (R8, R10), with commands, pinned tags and exit codes
  - **Consequences:** rootless under a dedicated service user (lingering enabled, quadlets in that user's unit path, `podman auto-update` as a user timer), the sidecar in userspace mode with no added capabilities, the 0002 verify step dry-running with `quadlet -dryrun -user`, Spike A's memory check, and the Phase 2 CLI using `podman`

  Every claim gets a primary-source link.
- [x] 4. **Edit `docs/project-plan.md`:**
  - D3: mark it resolved and link `decisions/0001-container-runtime-and-deployment.md`
  - component 9: "a liquid-sync stack for any Fedora IoT host; quadlets generated from `compose.yaml` by podlet; `podman auto-update`"
  - Phase 5: the same wording for its `deploy/pi/` bullet
  - open questions: answer "same Pi…" with "shared with other homelab services; host and other services live in a separate private repo (ADR 0001)"

  Nothing else in the plan changes.
- [x] 5. **Check and verify:**
  - the AC4 URL check, the AC5 leak grep and the AC1/AC2/AC6 greps
  - `docker context show` → `colima` (AC10)
  - `sdlc verify`

## Risks
- **The riskiest step is 1**, the only change outside the repo. Podman could take over the Docker socket and break the owner's Colima projects.
  - Mitigations: use the CLI only (no Podman Desktop or `podman-mac-helper`), record `docker context show` before and after, and check `docker ps` still shows Colima's containers.
  - Undo: `podman machine rm -f`, then remove the `.pkg` install (`/opt/podman`, plus its `/etc/paths.d/podman-pkg` entry if present) and Podman Desktop from `/Applications`. The `.pkg` installer adds `podman-mac-helper`, which must be uninstalled (`sudo /opt/podman/bin/podman-mac-helper uninstall`) or it takes over `/var/run/docker.sock`.
  - The standing rule to ask before installing software applies, and the step does ask.
- **`podman compose` delegates to `/opt/homebrew/bin/docker-compose`.** If it doesn't point that binary at Podman's socket, the sample could land in Colima. Step 2 checks exactly this. If it happens, the ADR records the fix: set `PODMAN_COMPOSE_PROVIDER` or the `compose_providers` setting, or use `podman-compose`, and the coexistence rules get updated.
- **Podlet's compose support is narrower than compose**, with no interpolation. The sample is deliberately written to the rules, so a podlet failure means the rules need tightening, not that the decision is wrong. If podlet can't convert even the minimal sample, that's a stop-and-report.
- **Unverified so far:** podlet's image name, maintenance status and licence (only the GitHub repo was seen during spec), and the quadlet dry-run path inside `quay.io/podman/stable`. Steps 2 and 3 check them, and nothing in the ADR states them unchecked.
- **Link rot (AC4):** some docs links from spec research are locale mirrors. The ADR uses English canonical URLs.
- **Out of scope by decision:** Pi clock and RTC guidance, and anything about the homelab repo.
- **Considered and rejected:** committing the sample compose as a fixture (0002 owns the real `compose.yaml`), and running the evidence in CI (no CI exists yet, and this is a one-off decision record).
- **Overlaps:** `sdlc dep 0006 --check` (run after this plan was written). 0002 already depends on 0006.

## Proof
- AC1: `grep -cE '^## (Context|Options|Decision|Consequences)$' docs/decisions/0001-container-runtime-and-deployment.md` → `4`, and `grep -E '^Status: accepted' …` matches.
- AC2: one `grep -ciE '<label>'` per R2 topic, each ≥ 1. The labels: Production OS, Rootless, Shared host, Source of truth, Local runtime, Podman compatibility, Compose rules, Memory budget, Colima.
- AC3: the Options section has `A`, `B` and `C` entries, each with "Costs" and "Gives up" lines.
- AC4: `grep -oE 'https?://[^) ]+' docs/decisions/0001-*.md | sort -u | xargs -n1 curl -sIL -o /dev/null -w '%{http_code} %{url}\n'` → no 4xx or 5xx.
- AC5: `git diff main -- docs | grep -E '^\+' | grep -v '127\.0\.0\.1' | grep -cE '([0-9]{1,3}\.){3}[0-9]{1,3}|\.ts\.net|mercuryrising'` → `0` (spec AC5 amended during build to exclude loopback).
- AC6: `awk '/^### Compose rules/{f=1;next} /^#/{f=0} f' <adr> | grep -c '^- \[ \]'` ≥ 7. (Compose rules, Local development, Why podlet and Evidence are `###` subsections of Decision. The original range form ended on its own start line.)
- AC7: the ADR contains "podlet" in the Options and Decision sections, and an "Evidence" heading with both commands and `exit 0`.
- AC8: `git diff main --stat -- docs/project-plan.md`, plus a read of the diff: only the D3, component 9, Phase 5 and open-questions hunks.
- AC10: `docker context show` → `colima`, and the Evidence block shows the sample in `podman ps` and not in `docker ps`.
- AC9: `sdlc verify` → `verify: PASS`.
- **Rollback:**
  - Repo: `git revert -m 1 <merge sha>` removes the ADR and the plan edits. A wrong decision found later is superseded by ADR 0002+, not edited.
  - Mac: `podman machine rm -f`, then remove `/opt/podman` and Podman Desktop (see Risks). Colima is untouched.

## Parallel tracks
<!-- None: a single document plus a small plan edit, done in order. -->
