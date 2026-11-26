# liquid-sync — Project Plan

_Created 2026-11-21. Living document: update as decisions are made._

## 1. Problem

Obsidian Sync works, but it's priced per vault tier (Standard: 1 vault and
1 month of history; multiple vaults need Plus), and history is capped at
12 months. Git-based plugins give real history but are unreliable on iOS and
push merge conflicts onto the phone. The goal is a setup with live sync on
every device, unlimited history, multiple vaults, and almost no upkeep.

## 2. Goals

1. **Seamless multi-device sync** for several vaults across macOS, iOS/iPadOS
   and Linux. Edits show up on other open devices within seconds.
2. **Complete, durable history**: every vault mirrored as plain Markdown in git,
   with no expiry, browsable with normal git tools, and pushed offsite.
3. **Effortless client onboarding**: a new device joins a vault with a setup URI
   or QR code plus a passphrase, in under two minutes.
4. **Safe migrations in both directions**: in from Obsidian Sync, iCloud, git or
   a plain folder; out to plain files, git or another service, at any time.
5. **No pets**: the host is disposable. It's rebuilt from this repo plus a data
   backup, and moving from laptop to Pi 4 needs no client changes.
6. **Private**: Tailscale only, valid HTTPS, LiveSync E2EE on.

### Non-goals (for now)

- Sharing vaults with other people or collaborative editing
- Public internet exposure or a web UI for notes
- Writing a custom sync engine. LiveSync already handles conflict resolution.

## 3. Components

| # | Component | Purpose | Notes |
|---|-----------|---------|-------|
| 1 | **CouchDB** | Sync backend, one database per vault | `couchdb:3.5`, with the settings LiveSync needs (CORS, `max_document_size`, `max_http_request_size`, `require_valid_user`). Config in `config/*.ini`, copied into CouchDB's `local.d/` at start. |
| 2 | **Tailscale access** | Stable private hostname plus HTTPS | `tailscale serve` → CouchDB. Use a dedicated node name (e.g. `liquid-sync`) through a Tailscale sidecar container, so the hostname moves with the stack instead of being tied to the laptop or the Pi. This is what makes host migration transparent. |
| 3 | **Bootstrap CLI** (`./liquid-sync`) | Single entry point for setup and operations | Bash. Subcommands: `init`, `vault add/list/remove`, `setup-uri`, `migrate in/out`, `backup`, `restore`, `doctor`. Idempotent. |
| 4 | **Archiver** | CouchDB → Markdown files → git commits | The LiveSync CLI follows the `_changes` feed of a one-way mirror of each vault database (`<vault>-archive`) and rebuilds files (LiveSync stores notes as chunks, encrypted when E2EE is on). A bash committer commits on a debounce (e.g. 10 minutes of quiet or hourly) and pushes to a private remote. See [ADR 0002](decisions/0002-archiver-approach.md). |
| 5 | **Client settings presets** | Consistent LiveSync configuration on every device | Settings JSON per profile (`desktop`, `mobile`), encoded into the setup URI: sync mode, hidden-file sync, exclusions for large attachments on mobile. |
| 6 | **Setup URI / QR generator** | Onboarding | Generate an encrypted LiveSync setup URI per vault (LiveSync ships a generator script) and print a terminal QR code for phones. |
| 7 | **Backup / restore** | Disaster recovery and host moves | CouchDB data snapshot (or replication to a file/second CouchDB) plus archive repos. `restore` brings up a new host from a backup. |
| 8 | **Health checks** (`doctor`) | Catch silent failures | TLS validity, CouchDB config drift, per-vault doc counts, archiver lag (time since last commit vs last change), last backup age. Later: alert through a push notification. |
| 9 | **Pi deployment** (`deploy/`) | Production host | A liquid-sync stack for any Fedora IoT host (the Pi 4 on a USB SSD is the reference), run rootless as a dedicated service user; quadlets generated from `compose.yaml` by podlet; `podman auto-update`. The host OS and other services aren't in this repo. See [ADR 0001](decisions/0001-container-runtime-and-deployment.md). |

## 4. Key design decisions to make

- **D1 — Archiver implementation** (Spike A):
  - (a) Headless Obsidian container (e.g. linuxserver/obsidian) with LiveSync and
    the Obsidian Git plugin. Fastest to stand up, but heavy (an Electron app on a
    Pi) and has GUI state to manage.
  - (b) An existing LiveSync file bridge or CLI from the LiveSync ecosystem, if a
    maintained one exists. Check this first.
  - (c) A custom service that reads `_changes`, reassembles chunks, decrypts and
    writes files. Lightest, but it depends on LiveSync's internal storage
    format, which can change between plugin versions.

  _Resolved:_ (b), the official LiveSync CLI, reading a one-way CouchDB
  mirror of each vault database, with a bash git committer. See
  [ADR 0002](decisions/0002-archiver-approach.md).
- **D2 — E2EE vs the archiver.** The archiver needs the vault passphrase to
  decrypt, so the server holds the key. That's acceptable for a self-hosted box
  over Tailscale, but it should be a conscious, documented choice in an ADR.
  Keep the passphrase in a git-ignored `*.env` file, never in git.
  _Resolved:_ E2EE stays on and the server holds each vault's passphrase in
  the archiver's git-ignored env file. See
  [ADR 0002](decisions/0002-archiver-approach.md).
- **D3 — Docker vs Podman locally.** _Resolved:_ Podman machine locally,
  alongside Colima; the compose file still works with both. See
  [ADR 0001](decisions/0001-container-runtime-and-deployment.md).
- **D4 — Archive remote.** Self-hosted Forgejo, GitHub private repos, or both.
- **D5 — Passphrase handling.** One passphrase per vault, stored in a password
  manager, entered once per device. The setup URI is itself encrypted with a
  separate one-time passphrase.

## 5. Migrations

### 5.1 Migrating in (existing vault → liquid-sync)

These rules apply whatever the source:

1. **Back up first.** `migrate in` refuses to run until it has made a zip or
   tarball of the source vault folder.
2. **One source of truth.** Pick a single seed device, normally the Mac, whose
   copy of the vault is complete and current.
3. **Turn off the old sync everywhere** before connecting LiveSync. Two sync
   engines writing to one folder causes duplicates and conflicts.
4. **Seed from one device, fetch on the rest.** The seed device uploads to an
   empty remote database. Every other device creates a **new, empty** local
   vault and fetches from the remote using the setup URI. Never merge two
   existing local copies.
5. **Verify.** `migrate in` compares file count and a content hash between the
   seed folder and the first archiver output, and reports any mismatch.

Source-specific steps:

| Source | Extra steps |
|--------|-------------|
| **Obsidian Sync** | Make sure the seed device is fully synced. Disconnect Sync on every device (Settings → Sync → disconnect), keep the subscription until verification passes, then cancel. Optionally export Sync version history first, since it won't carry over. |
| **iCloud** | On iOS, the new vault must be created under "On My iPhone", not iCloud Drive. On the Mac, move the seed vault out of iCloud Drive (or exclude it) so iCloud stops syncing it. |
| **Git (Obsidian Git plugin)** | Disable the plugin on all devices. Optionally import the existing git history into the archive repo, so history continues instead of restarting (`git` remote add + merge with unrelated histories, or replay). |
| **Plain folder / other** | Copy into place on the seed device, then continue as above. |

Also capture **`.obsidian` config**: decide per vault whether LiveSync's
customization sync carries plugins, themes and hotkeys, or whether config stays
per device. Default: sync it on desktops, review it for mobile.

### 5.2 Migrating out (liquid-sync → elsewhere)

The archive repo is the exit path: a plain Markdown vault plus full history.

- **To plain files or another tool:** `migrate out <vault> --to folder` checks
  out the latest archive commit into a folder (or zip).
- **To git-only:** hand over the archive repo as is.
- **Back to Obsidian Sync (or similar):** pick a seed device, disable LiveSync on
  all devices, enable the new service on the seed, and have the other devices
  join fresh. Same "one seed, others fetch" rule as migrating in.
- **Decommission:** export, verify, then `vault remove` deletes the database
  (with confirmation), and the archive repo is kept.

### 5.3 Migrating the host (laptop → Pi, Pi → replacement)

- Clients point at the Tailscale node name, not the machine. Move the Tailscale
  node identity with the stack, or re-register the same node name on the new
  host.
- Procedure: `backup` on the old host → provision the new host
  (`deploy/`) → `restore` → take the old host offline → `doctor`. Clients
  reconnect with no changes.
- Alternative with no downtime: CouchDB replication from the old host to the
  new one, then cut the hostname over.
- Also a migration: **LiveSync plugin and CouchDB upgrades.** Pin versions,
  read release notes, and test on a fixture vault before upgrading clients.
  Per LiveSync guidance, keep plugin versions in line across devices.

## 6. Client onboarding (the "seamless" part)

Target experience for adding a device to a vault:

1. Install Obsidian and make sure Tailscale is installed and connected (on iOS,
   turn on VPN On Demand).
2. Create an empty vault with the vault's name (on iOS, under "On My iPhone").
3. Install and enable Self-hosted LiveSync from Community Plugins.
4. On the server, run `./liquid-sync setup-uri <vault> --profile mobile`. It
   shows a QR code or URI and a one-time passphrase.
5. Paste the URI with "Use the copied setup URI" in the command palette, enter
   the passphrases, and choose **fetch from remote**.

The setup URI carries the server URL, credentials, E2EE passphrase and the
settings preset, so nothing is typed by hand. Docs to write: `docs/runbooks/add-device.md`,
with screenshots for iOS and macOS.

Things to decide for presets: LiveSync mode (live vs periodic on mobile for
battery), hidden-file and customization sync, mobile exclusions (large PDFs and
videos), and per-device names for conflict attribution.

## 7. Phases

### Phase 0 — Repo scaffold _(this commit)_
- README, CLAUDE.md, project plan, .gitignore

### Phase 1 — Local stack, manual flow
- `compose.yaml` with CouchDB 3.5 + `config/*.ini`
- Per-service env files with committed examples: `couchdb.env.example` (admin
  user/password), and later the vault list and the Tailscale auth key in their
  own services' files
- Tailscale sidecar + `tailscale serve` for HTTPS on a dedicated node name
- Manually connect one Mac and one iPhone to a **test** vault and confirm live
  sync both ways
- ADR 0001: Docker vs Podman locally

### Phase 2 — Bootstrap CLI
- `liquid-sync init`: generate the per-service `*.env` files, start the stack, apply CouchDB config
  through its HTTP API (idempotent), wait for health
- `vault add/list/remove`: create the database and its user/permissions
- `setup-uri`: generate the encrypted URI and a terminal QR code
- `doctor` v1
- `shellcheck` in a pre-commit hook

### Phase 3 — Archiver
- Spike A (D1): evaluate options (b) → (a) → (c), write ADR 0002. Done: see
  [ADR 0002](decisions/0002-archiver-approach.md)
- Implement the archiver with a debounced commit and push
- Round-trip test: fixture vault → CouchDB → archiver → diff
- Add archiver lag to `doctor`

### Phase 4 — Migrations
- `migrate in` with backup, verification and source-specific checklists
- Git history import option
- `migrate out` (folder, git)
- Migrate the first real vault (lowest stakes first), live with it for 1–2 weeks

### Phase 5 — Backup / restore and the Pi
- `backup` / `restore` and a scheduled backup
- `deploy/`: a liquid-sync stack for any Fedora IoT host, run rootless;
  quadlets generated from `compose.yaml` by podlet; `podman auto-update`
- Host migration drill: laptop → Pi using `restore`, with no client changes
- Migrate the remaining vaults

### Phase 6 — Polish
- Alerts (archiver stalled, backup stale, cert expiry)
- Nicer commit messages (notes changed, device)
- Optional: a small read-only history browser over the archive repos

## 8. First steps (next session)

1. Write `couchdb.env.example` and `compose.yaml` (CouchDB 3.5 only) and bring it up
   locally on port 5984 bound to localhost.
2. Add a `config/*.ini` file with the LiveSync-required CouchDB settings and check
   them against the plugin's current docs.
3. Create `test/fixtures/sample-vault/` with a few notes, an image and nested
   folders.
4. Manually connect the Mac test vault over `localhost`, then add the Tailscale
   sidecar and connect the iPhone over HTTPS.
5. Start Spike A: look for a maintained LiveSync file-bridge or CLI before
   considering the other archiver options.

## 9. Open questions

- Which vaults, and how big are they (especially attachments)? That sets Pi
  storage and mobile exclusion defaults.
- Should `.obsidian` plugin config sync across devices, or stay per device?
- Archive remote: Forgejo on the homelab, GitHub, or both?
- How long to keep CouchDB history? LiveSync keeps revisions, so periodic
  compaction is needed once git holds the long-term history.
- ~~Use the same Pi as other homelab services, or a dedicated one?~~ Shared
  with other homelab services; the host and other services live in a separate
  private repo (ADR 0001).
