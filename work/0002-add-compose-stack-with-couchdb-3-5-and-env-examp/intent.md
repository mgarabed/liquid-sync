---
id: 0002
title: Add compose stack with CouchDB 3.5 and .env.example
type: feature
status: building
risk: low
tier: standard
priority: P2
author: Mike Garabedian
created: 2026-11-21
branch: work/0002-add-compose-stack-with-couchdb-3-5-and-env-examp
pr: 
depends: 0006
spec_hash: requirements=f30726b3b4a0;acceptance-criteria=ba4791da0cca;areas-of-concern=08320bfc51c1
started: 2026-11-22T17:54:26+00:00
---
# Intent: Add compose stack with CouchDB 3.5 and .env.example

## Problem
No stack exists yet. We need a `compose.yaml`, working with both `docker compose` and `podman compose`, that runs `couchdb:3.5` bound to localhost:5984, plus a `.env.example` (project plan Phase 1, first step 1). ADR 0001 adds two more requirements. The file must follow the ADR's compose rules. The quadlets generated from it by podlet must be committed and checked, so that what runs on the laptop is provably what will run on the Pi.

## Proposed outcome
- From a clean checkout, the owner copies `.env.example`, fills in an admin user and password, and brings CouchDB up locally with `podman compose up -d`. CouchDB answers on loopback port 5984 only and rejects requests without credentials.
- The same `compose.yaml` comes up under `docker compose` too.
- The CouchDB data volume survives `down`/`up`.
- The quadlets generated from `compose.yaml` by podlet are committed under `deploy/`, and a check script in the repo regenerates them, fails on any difference, and dry-runs them with `quadlet -dryrun -user`. All of this runs in digest-pinned containers.
- The stack runs on the dev Mac's rootless Podman machine, matching the Pi. This is the ADR's first exercise of rootless runtime.

## Affected users and systems
- The owner, as the first and only operator, on the dev Mac.
- New files: `compose.yaml`, `.env.example`, generated quadlets under `deploy/`, and a check script.
- Later items build on it: 0003 (CouchDB config), 0005 (Tailscale sidecar), and the Phase 2 CLI.

## Constraints
- Every rule in ADR 0001's compose-rules checklist, applied line by line.
- The memory limits leave room in the 1 GB budget for the sidecar and the archiver.
- ADR 0001's local-development rules:
  - use `podman` commands only
  - leave Docker contexts and `DOCKER_HOST` alone, so Colima stays untouched
  - bind host ports to loopback, checked against ports already in use
- `podman` is at `/opt/podman/bin/podman` from the `.pkg` installer, and isn't on every shell's PATH. `podman-mac-helper` is installed there. The ADR requires it to be inactive, and 0002 checks that `/var/run/docker.sock` doesn't point at Podman.
- No secrets in git. `.env` is already git-ignored. `.env.example` holds placeholders only.
- Ask before installing any software.

## Out of scope
- Adding the verify step to `.sdlc/config.toml`. That's control plane, so it needs the high tier. A small high-tier follow-up item wires 0002's check script into `sdlc verify`.
- The Tailscale sidecar, and proving that `tailscale serve` works in userspace mode. Both move to 0005, which reopens ADR 0001 if it doesn't work.
- `config/local.ini` and the LiveSync settings (0003).
- `.env.example` entries for the vault list (the Phase 2 CLI) and the Tailscale auth key (0005, in its own env file so CouchDB never sees it).
- Deploying to the Pi, installing the service user and quadlets, and setting up `podman auto-update` (Phase 5).

## Open questions
- [ ] Env file layout: one `.env` per service (e.g. `env/couchdb.env`), or a single `.env` that only CouchDB reads for now? CLAUDE.md says secrets live in `.env`. With `env_file:` and no interpolation, each container sees every key in its file.
- [ ] Where do the generated quadlets live: `deploy/pi/` as the project plan names it, or `deploy/quadlets/`, since the ADR says nothing in `deploy/` is specific to the Pi?
- [ ] Does CouchDB 3.5 need a single-node setup step (`_users` and the system DBs) for this item to count as working, or does that belong to 0003?
- [ ] Are the named volume and `container_name` stable across `docker compose` and `podman compose`, so switching engines doesn't orphan data?

## Tier
standard — new stack files and a check script, no sensitive or control-plane paths (the verify-step wiring is split out)
