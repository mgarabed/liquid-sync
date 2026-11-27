# liquid-sync

Self-hosted, low-maintenance sync and history for personal Obsidian vaults.

- **Live sync across devices** (macOS, iOS/iPadOS, Linux) using the
  [Self-hosted LiveSync](https://github.com/vrtmrz/obsidian-livesync) plugin
  backed by CouchDB.
- **Full history in git**: a server-side archiver writes each vault out as plain
  Markdown and commits on a schedule, so phones never touch git.
- **Private by default**: reachable only over Tailscale, with HTTPS from
  Tailscale certs and LiveSync end-to-end encryption.
- **Cattle, not a pet**: everything is containers plus config in this repo.
  Prototype locally, then move to a Raspberry Pi 4 (or anything else) by
  restoring data, with no client reconfiguration.

> Status: planning / prototype. See [docs/project-plan.md](docs/project-plan.md).

## Architecture

```
 iPhone / iPad / Mac / Linux
   Obsidian + Self-hosted LiveSync plugin
            │  HTTPS over Tailscale (Service svc:liquid-sync)
            ▼
 ┌──────────────────────────────── host (Pi 4) ────────┐
 │  tailscale serve ──► CouchDB (1 database per vault) │
 │                         │ _changes feed             │
 │                         ▼                           │
 │                     archiver ──► vault-as-files ──► git repo ──► private remote
 │  backup job ──► CouchDB snapshot                    │
 └─────────────────────────────────────────────────────┘
```

## Run locally

The stack so far is CouchDB alone, bound to `127.0.0.1:5984`. Local
development uses [Podman machine](https://docs.podman.io/en/stable/markdown/podman-machine-init.1.html)
(rootless); see [ADR 0001](docs/decisions/0001-container-runtime-and-deployment.md).
If `podman` isn't on your PATH, it's at `/opt/podman/bin/podman`.

```sh
cp couchdb.env.example couchdb.env   # then set COUCHDB_PASSWORD; CouchDB won't start without it
podman compose up -d
curl -u admin:<password> http://127.0.0.1:5984/_up
podman compose down                  # add -v to delete the data volume too
```

CouchDB is configured for Self-hosted LiveSync by `config/20-livesync.ini`, and
`scripts/check-couchdb-config` checks that the running node still matches it.
To test syncing from Obsidian with a throwaway vault, follow
[the local sync test runbook](docs/runbooks/local-sync-test.md).

After editing `compose.yaml`, regenerate the quadlets and review the diff:

```sh
scripts/check-quadlets --write
```

## Planned CLI

All operations go through one bootstrap script (not yet implemented):

```sh
./liquid-sync init                 # create env files, start the stack, configure CouchDB
./liquid-sync vault add <name>     # create a vault database + archive repo
./liquid-sync setup-uri <vault>    # print setup URI / QR code for a device
./liquid-sync migrate in <vault>   # guided import from Obsidian Sync / iCloud / git / folder
./liquid-sync migrate out <vault>  # export to plain files / git / another sync service
./liquid-sync backup | restore     # snapshot and restore server state
./liquid-sync doctor               # health checks (TLS, CouchDB config, archiver lag)
```

## Layout (planned)

```
liquid-sync              # bootstrap/CLI script (bash)
compose.yaml             # CouchDB + archiver, docker or podman
config/                  # CouchDB *.ini (copied into local.d/), LiveSync presets
archiver/                # CouchDB → files → git service
deploy/quadlets/         # quadlet units generated from compose.yaml (Fedora IoT)
deploy/hooks/            # post-install, backup, restore hooks the host tool runs
docs/                    # plan, runbooks, decision records
```

## Requirements

- Docker or Podman with compose support
- Tailscale account with MagicDNS and HTTPS certificates on. The owner's
  deployment is published as the Tailscale Service `svc:liquid-sync` by a
  separate homelab repo (homelab ADR 0005); the stack itself only binds
  CouchDB to `127.0.0.1:5984`
- Obsidian 1.7.2+ with Self-hosted LiveSync on each device
