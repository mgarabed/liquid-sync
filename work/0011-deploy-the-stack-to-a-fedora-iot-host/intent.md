---
id: 0011
title: Deploy the stack to a Fedora IoT host
type: feature
status: planned
risk: low
tier: standard
priority: P2
author: Mike Garabedian
created: 2026-11-25
branch: 
pr: 
source: 0006
depends: 0016
spec_hash: requirements=86e94cc14441;acceptance-criteria=dd651c4a7432;areas-of-concern=c2d88599546c
---
# Intent: Deploy the stack to a Fedora IoT host

## Problem
Install the liquid-sync quadlets rootless under a dedicated service user with lingering on a Fedora IoT host, and prove CouchDB runs there (rootless, SELinux, arm64) with a throwaway vault; backup/restore and the host-move drill stay in Phase 5.

Rescoped 2026-11-27. The host side has settled how a stack is installed: a host tool, owned outside this repo, installs a bundle that a stack ships at a git tag. The contract is in `docs/decisions/0003-host-bundle-contract.md`. liquid-sync's job is now to ship its bundle in that layout and keep the contract's promises. Installing it (the service user, lingering, copying files, writing `couchdb.env`, restarting units) belongs to the host tool.

The bundle is close today. `couchdb.container` already publishes only `127.0.0.1:5984`, reads `EnvironmentFile=couchdb.env`, starts at boot, pins `couchdb:3.5` and names its container `liquid-sync-couchdb`. `liquid-sync.network` uses the default driver. One gap remains: `Volume=./config:/liquid-sync/config:ro,Z` resolves against the installed quadlet directory, but `config/` lives at the repo root, so the CouchDB `*.ini` files wouldn't be installed.

## Proposed outcome
- `deploy/quadlets/` is a complete bundle. It holds the podlet-generated quadlets plus every config file they mount, so the `*.ini` files ship in `deploy/quadlets/config/`.
- `scripts/check-quadlets` (run by `sdlc verify`) checks the contract as well as the podlet diff:
  - Only `.container`, `.volume`, `.network` and `.pod` files, plus the files they mount.
  - Regular files only.
  - The copies in `deploy/quadlets/` (the `config/*.ini` files and `couchdb.env.example`) match their sources at the repo root.
  - The quadlets keep the port, network, env-file, volume, boot and image-tag promises.
- A tag of this repo is a bundle the host tool can install.
- The proof: a host tool following the contract brings CouchDB up rootless on Fedora IoT (arm64, SELinux) with a throwaway vault. That run waits for the host tool, which isn't built yet. The bundle is built and checked now.

## Affected users and systems
- `deploy/quadlets/`, which gains `config/` and a copy of `couchdb.env.example`.
- `compose.yaml`, `config/` and `scripts/check-quadlets`.
- `couchdb.env.example`.
- ADR 0001, already amended for the contract, and the new ADR 0003.
- The production Pi, the first host the bundle is installed on. The host tool and the host setup live outside this repo.

## Constraints
- Follow the bundle contract in ADR 0003:
  - Quadlets need nothing newer than Podman 5.0.
  - No `PodmanArgs=`.
  - `Network=` is only the stack's own `.network` or none.
  - Only `PublishPort=127.0.0.1:5984:5984`.
  - `EnvironmentFile=couchdb.env` by relative name.
  - Named volumes for all data; any `.volume` file sets `VolumeName=`.
  - Images pinned to a tag.
- Nothing in liquid-sync needs root. The bundle carries no installer and no manifest.
- Ship only `couchdb.env.example`, never `couchdb.env`. The host writes the real one.
- `compose.yaml` stays the source of truth and keeps working with both `docker compose` and `podman compose` locally (ADR 0001).
- Test with a throwaway vault from `test/fixtures/` only.

## Out of scope
- The host tool itself, the service user, lingering, tailscaled and `svc:liquid-sync` publishing. These are all owned by the host side.
- `deploy/hooks/post-install`, which is 0012's init run as a hook. The bundle ships without it.
- `deploy/hooks/backup` and `deploy/hooks/restore`, and the host-move drill (Phase 5).
- HTTPS and the iPhone test (0005).

## Open questions
- [x] How do the `*.ini` files get into `deploy/quadlets/config/`? — They're copied. `config/` at the repo root stays the source of truth and `./config` stays the compose mount. `check-quadlets --write` copies the files into `deploy/quadlets/config/`, and check mode fails on any difference. This keeps the config independent of quadlets: another deployment model would copy from `config/` too.
- [x] Does `couchdb.env.example` need to ship inside `deploy/quadlets/`? — Yes, as a copy kept in sync by `check-quadlets`, like the `.ini` files. The installed bundle has no repo root.
- [x] Can 0011 ship a bundle with no `post-install` hook? — Yes. The CouchDB config is all in the `.ini` files, which load when the container starts, and the admin comes from the env file the host writes. So the installed stack is ready for LiveSync without init. 0012 adds the hook later, and 0011 → 0005 doesn't wait on it. Until 0013 exists, the test vault's database is created by hand, as the local runbook does.
- [ ] Podman 5.0 floor: dry-run the quadlets with `quadlet -dryrun -user` in a Podman 5.0 image, pinned by digest. Should this be a one-time check during the build, or a standing step in `check-quadlets`? A standing step would catch a key newer than 5.0 that arrives with a later `compose.yaml` edit or a podlet bump. It costs one more container run per verify. Settle this in the spec.

## Tier
standard — deploy layout and a check script; installing on a host is the host tool's job.
