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
            │  HTTPS over Tailscale (stable MagicDNS name)
            ▼
 ┌──────────────────────────── host (laptop → Pi 4) ───┐
 │  tailscale serve ──► CouchDB (1 database per vault) │
 │                         │ _changes feed             │
 │                         ▼                           │
 │                     archiver ──► vault-as-files ──► git repo ──► private remote
 │  backup job ──► CouchDB snapshot                    │
 └─────────────────────────────────────────────────────┘
```

## Planned CLI

All operations go through one bootstrap script (not yet implemented):

```sh
./liquid-sync init                 # create .env, start the stack, configure CouchDB
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
compose.yaml             # CouchDB + archiver (+ tailscale sidecar), docker or podman
config/                  # CouchDB local.ini, LiveSync settings presets
archiver/                # CouchDB → files → git service
deploy/pi/               # Fedora IoT + quadlet units for the Pi
docs/                    # plan, runbooks, decision records
```

## Requirements

- Docker or Podman with compose support
- Tailscale account (HTTPS certificates enabled on the tailnet)
- Obsidian 1.7.2+ with Self-hosted LiveSync on each device
