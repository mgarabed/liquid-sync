# 0002 — Archiver approach and E2EE key handling

Status: proposed
Date: 2026-11-26
Work item: `work/0007-spike-a-choose-the-archiver-approach-adr-0002`

## Context

_To be written in step 5._

## Options

_To be written in step 5._

## Decision

_To be written in step 5._

## Consequences

_To be written in step 5._

## Working notes

Raw evidence, moved into Evidence in step 5. All read on 2026-11-26 unless
stated. Labels: `documented` (the project's own docs or README say so),
`read in source` (seen in code, CI config, registry manifests or issue
threads), `inferred` (my reading, not stated anywhere).

### Option (b): bridges and CLIs

Candidates found by following every tool linked from the LiveSync README and
`docs/`, plus a GitHub search for `livesync headless`, `livesync git` and
`obsidian-livesync cli`.

**Self-hosted LiveSync CLI** (`src/apps/cli` in the plugin repo)

- Repo: [vrtmrz/obsidian-livesync, src/apps/cli](https://github.com/vrtmrz/obsidian-livesync/tree/main/src/apps/cli) (read 2026-11-26). Maintainer vrtmrz, the plugin's author. Licence MIT, the plugin repo's licence ([repo metadata](https://github.com/vrtmrz/obsidian-livesync), read 2026-11-26). `read in source`
- "Command-line version of Self-hosted LiveSync plug-in for syncing vaults without Obsidian", "built using the same core as the Obsidian plug-in", and "Supports all core sync features (encryption, conflict resolution, etc.)" ([CLI README](https://github.com/vrtmrz/obsidian-livesync/blob/main/src/apps/cli/README.md), read 2026-11-26). `documented`
- Releases: CLI images are tagged from the plugin's release tags with a `-cli` suffix (`1.0.52-cli` … `1.0.44-cli`, plus CLI-only patches such as `1.0.46-patch2-cli`) ([repo tags](https://github.com/vrtmrz/obsidian-livesync/tags), read 2026-11-26). The CLI's `package.json` version is `1.0.52-cli`, matching plugin 1.0.52 ([package.json](https://github.com/vrtmrz/obsidian-livesync/blob/main/src/apps/cli/package.json), read 2026-11-26). `read in source`
- Cadence: the plugin shipped 40 releases between 2026-08-15 (1.0.15) and 2026-11-22 (1.0.52), several a week ([releases](https://github.com/vrtmrz/obsidian-livesync/releases), read 2026-11-26). `read in source`
- Output: `mirror` and `daemon` write the vault as plain files to a directory (`--vault`). It keeps its own PouchDB copy of the database in the database directory ([CLI README](https://github.com/vrtmrz/obsidian-livesync/blob/main/src/apps/cli/README.md), read 2026-11-26). `documented`
- Direction: `daemon` "continuously syncs changes in both directions", including "local filesystem → CouchDB: via chokidar file watching. Any file created, modified, or deleted in the vault directory is pushed to CouchDB". `mirror` is also bidirectional. One-shot `sync` runs "one replication cycle", and `ls`, `cat`, `pull`, `info` and `cat-rev` read from the local database ([CLI README](https://github.com/vrtmrz/obsidian-livesync/blob/main/src/apps/cli/README.md), read 2026-11-26). There is no documented read-only or pull-only mode. `documented`
- E2EE and path obfuscation: settings take `encrypt` and `passphrase`, the same format as the plugin, and a setup URI can be applied with `setup` ([CLI README](https://github.com/vrtmrz/obsidian-livesync/blob/main/src/apps/cli/README.md), read 2026-11-26). `documented`
- Runtime: Node.js 22.22 or later. Dependencies include PouchDB 9 with the LevelDB adapter, chokidar and werift (WebRTC) ([package.json](https://github.com/vrtmrz/obsidian-livesync/blob/main/src/apps/cli/package.json), read 2026-11-26). `read in source`
- Image: `ghcr.io/vrtmrz/livesync-cli`, built on `node:22-slim`, entrypoint `livesync-cli`, data volume `/data` ([Dockerfile](https://github.com/vrtmrz/obsidian-livesync/blob/main/src/apps/cli/Dockerfile), read 2026-11-26). CI builds amd64 and arm64 on native runners and publishes one multi-platform index; stable releases get `<version>-cli`, `<major.minor>-cli`, `latest` and a SHA tag ([cli-docker.yml](https://github.com/vrtmrz/obsidian-livesync/blob/main/.github/workflows/cli-docker.yml), read 2026-11-26). `read in source`
- Registry check: `1.0.52-cli` resolves to index `sha256:cf9c28ca544e5e84e8825185a81032559c5503ad812c6cd66be4a714bca78a4f` with amd64 and arm64 manifests; the arm64 image is 91.8 MB compressed ([ghcr.io/vrtmrz/livesync-cli](https://github.com/vrtmrz/obsidian-livesync/pkgs/container/livesync-cli), registry API read 2026-11-26). `read in source`
- Memory: nothing documented. A Node process holding PouchDB/LevelDB for a vault under 500 MB should sit well under 512 MB. `inferred`
- Open issues touching data safety and storage (read 2026-11-26, `read in source`):
  - [#1143](https://github.com/vrtmrz/obsidian-livesync/issues/1143) (2026-08-27): the daemon's startup scan deleted 76 documents from CouchDB because a partially warmed file cache truncated the listing. The maintainer says the fix shipped in 1.0.29; the issue is still open.
  - [#1304](https://github.com/vrtmrz/obsidian-livesync/issues/1304) (2026-10-31): `fetch --force` without `--write-settings` left later commands on an empty database; the daemon re-uploaded every file and local files were deleted. Fixed in 1.0.44, per the maintainer.
  - [#835](https://github.com/vrtmrz/obsidian-livesync/issues/835) (2026-03-25): chunks reportedly not replicated on push; the reporter later corrected their own measurements. Still open.
  - [#1365](https://github.com/vrtmrz/obsidian-livesync/issues/1365) (2026-11-17): `fetch --force` aborts on a legacy encrypted chunk document.
  - [#1346](https://github.com/vrtmrz/obsidian-livesync/issues/1346), [#1328](https://github.com/vrtmrz/obsidian-livesync/issues/1328): daemon rescans and missed files in new directories.
- Supported LiveSync versions: released in lockstep with the plugin from the same source tree and shared core (`@vrtmrz/livesync-commonlib`), so a CLI tag matches the plugin of the same number. `inferred` from the tagging above.
- Takeaway: every data-loss report above comes from the CLI *writing* (the daemon's file watcher or a rebuild). An archiver only needs remote → local. `inferred`

**LiveSync Bridge**

- Repo: [vrtmrz/livesync-bridge](https://github.com/vrtmrz/livesync-bridge) (read 2026-11-26). Maintainer vrtmrz. "The Unified Version of filesystem-livesync and livesync-classroom", "multi-directional" ([readme](https://github.com/vrtmrz/livesync-bridge/blob/main/readme.md), read 2026-11-26). `documented`
- Licence: none. GitHub reports no licence and the repo has no LICENSE file ([repo contents](https://github.com/vrtmrz/livesync-bridge), read 2026-11-26), so by default no right to redistribute. `read in source`
- Releases: no tags and no releases. The readme says "This Bridge implementation remains unreleased" and pins Commonlib 0.3.1. Last commit 2026-11-04 ([commits](https://github.com/vrtmrz/livesync-bridge/commits/main), read 2026-11-26). `read in source`
- Runtime: Deno. Docker instructions build from the repo's Dockerfile with `docker compose up`; no published image found ([readme](https://github.com/vrtmrz/livesync-bridge/blob/main/readme.md), read 2026-11-26). `documented`
- Output: storage peers write plain files to a folder; supports `passphrase`, `obfuscatePassphrase` and the newer separate ID key ([readme](https://github.com/vrtmrz/livesync-bridge/blob/main/readme.md), read 2026-11-26). `documented`
- Open issues (read 2026-11-26, `read in source`): [#88](https://github.com/vrtmrz/livesync-bridge/issues/88) a file whose chunks arrive after its entry "is dropped for good"; [#64](https://github.com/vrtmrz/livesync-bridge/issues/64) watch checkpoint never persisted, restarts skip missed changes; [#73](https://github.com/vrtmrz/livesync-bridge/issues/73) sync to filesystem sometimes stops; [#84](https://github.com/vrtmrz/livesync-bridge/issues/84) "Deno is discontinued in a year".

**filesystem-livesync**

- [vrtmrz/filesystem-livesync](https://github.com/vrtmrz/filesystem-livesync): "integrated into LiveSync Bridge, and will be no longer maintained". MIT, last push 2023-12-01, claims compatibility with LiveSync 0.13.0 ([README](https://github.com/vrtmrz/filesystem-livesync/blob/main/README.md), read 2026-11-26). Ruled out: unmaintained, and LiveSync is now 1.0.x. `documented`

**Community tools** (GitHub search, read 2026-11-26)

- [Skyxim/livesync-git-backup](https://github.com/Skyxim/livesync-git-backup): runs the LiveSync CLI daemon (from a personal fork) in compose and commits the vault folder to a bare git repo on a timer. Created and last pushed 2026-10-07, no licence, no releases, 0 stars. `read in source`. It is the same shape this ADR is weighing, but not something to depend on.
- [tgmstudios/obsidian-livesync-headless](https://github.com/tgmstudios/obsidian-livesync-headless): an independent Node reimplementation, bidirectional, MIT, 11 stars, no releases, last push 2026-09-29. `read in source`. A third-party reimplementation of the storage format has the costs of option (c) without our control over it.
- Other hits (`gmcouto/obsidian-livesync-headless`, `MrYadro/livesync-headless`, `atty303/obsidian-livesync-cli`, …) have 0–1 stars and no releases. Not evaluated further.

### Option (a): headless Obsidian

**linuxserver/obsidian**

- Repo: [linuxserver/docker-obsidian](https://github.com/linuxserver/docker-obsidian) (read 2026-11-26). Maintained by the LinuxServer.io team, image build scripts GPL-3.0. Weekly rebuilds: `v1.15.1-ls154` on 2026-11-22, `ls153` on 2026-11-15, `ls152` on 2026-11-08 ([releases](https://github.com/linuxserver/docker-obsidian/releases), read 2026-11-26). `read in source`
- What it is: Obsidian's desktop AppImage on the [Selkies base image](https://github.com/linuxserver/docker-baseimage-selkies), which "streams a desktop or single application to your web browser" on ports 3000/3001 ([README](https://github.com/linuxserver/docker-obsidian/blob/master/README.md), read 2026-11-26). `documented`. The arm64 Dockerfile downloads the upstream `Obsidian-<version>-arm64.AppImage` at build time ([Dockerfile.aarch64](https://github.com/linuxserver/docker-obsidian/blob/master/Dockerfile.aarch64), read 2026-11-26). `read in source`
- Architectures: amd64 and arm64 ([README](https://github.com/linuxserver/docker-obsidian/blob/master/README.md), read 2026-11-26). `documented`. The `1.15.1` index has amd64 and arm64 manifests; the arm64 image is 1218.3 MB compressed, 13× the LiveSync CLI image ([ghcr.io/linuxserver/obsidian](https://github.com/linuxserver/docker-obsidian/pkgs/container/obsidian), registry API read 2026-11-26). `read in source`
- Runtime needs: `--shm-size=1gb`, "needed for electron applications to function properly" ([README](https://github.com/linuxserver/docker-obsidian/blob/master/README.md), read 2026-11-26). `documented`. An archiver would also need an X/Wayland desktop, the streaming stack and Electron running around the clock. `inferred`
- Security: "By default there is no authentication", and "the web interface includes a terminal with passwordless `sudo`, anyone who can reach the GUI can gain root inside the container" ([README](https://github.com/linuxserver/docker-obsidian/blob/master/README.md), read 2026-11-26). `documented`
- Memory: [obsidian-livesync#428](https://github.com/vrtmrz/obsidian-livesync/issues/428) "Efficient RAM usage on obsidian-docker": LiveSync sync in this image "takes too much RAM and crashes the raspberry pi"; a later commenter reports it topping a 2 GB VPS limit, and the maintainer says the earlier fix "did not establish that this workload was resolved" (read 2026-11-26). `read in source`. A 1 GB shm allowance alone equals ADR 0001's whole budget. `inferred`
- Rootless: LinuxServer images start as root under s6 and drop to `PUID`/`PGID` ([README](https://github.com/linuxserver/docker-obsidian/blob/master/README.md), read 2026-11-26). `documented`. Under rootless Podman that is root in a user namespace, which usually works but is untested here. `inferred`
- Plugins and GUI state: LiveSync and Obsidian Git are installed into the vault's `.obsidian/plugins/` and configured through Obsidian's UI or by writing their `data.json`. Pinning means committing plugin files and settings that Obsidian itself can rewrite. `inferred`
- Obsidian Git: [Vinzent03/obsidian-git](https://github.com/Vinzent03/obsidian-git), MIT, 2.44.0 on 2026-11-23, roughly monthly releases (read 2026-11-26). `read in source`
- Obsidian's terms: "Obsidian is free for all purposes, including personal, commercial, and non-profit use"; commercial licences are optional. The licence summary says nothing about servers, headless or automated use, or redistribution, and reserves rights to "code in the app" ([obsidian.md/license](https://obsidian.md/license), last updated 2025-02-20, read 2026-11-26). `documented`. Running it for ourselves looks allowed; the image redistributes the AppImage, which is LinuxServer's question, not ours, since we'd only pull it. `inferred`
- Version coupling: two pins (Obsidian in the image tag, LiveSync in the vault's plugin folder). LinuxServer tags follow Obsidian versions, so `podman auto-update` within a pinned tag only picks up `-lsNNN` rebuilds. `inferred`

### Option (c): a custom `_changes` reader

- Authority: the data-structure doc "is not a stable, forward-compatible API for constructing CouchDB documents by hand"; the "executable authority" for identifiers, chunking, encryption, compression and reconstruction "is the exact `@vrtmrz/livesync-commonlib` version recorded in the repository lockfile" ([datastructure.md](https://github.com/vrtmrz/obsidian-livesync/blob/main/docs/datastructure.md), written against LiveSync 1.0.24, read 2026-11-26). `documented`
- Document model: file Metadata holds `path` and `children`, the chunk document IDs "in reconstruction order"; chunks are `leaf` documents (`h:` IDs, `h:+` when the ID incorporates encryption material); text is `plain`, binaries `newnote` as Base64. The Metadata and its chunks are "separate database operations rather than one" transaction, so a reader can see Metadata before its chunks arrive. Deletion is logical and doesn't clear `children` ([datastructure.md](https://github.com/vrtmrz/obsidian-livesync/blob/main/docs/datastructure.md), read 2026-11-26). `documented`
- Path obfuscation: "the body of the document ID is replaced by an `f:` SHA-256-derived value"; compression, E2EE and obfuscation "can change raw remote identifiers and properties" ([datastructure.md](https://github.com/vrtmrz/obsidian-livesync/blob/main/docs/datastructure.md), read 2026-11-26). `documented`
- E2EE V2: PBKDF2 (310,000 iterations, 32-byte salt) derives a master key from the passphrase, HKDF derives per-chunk keys, AES-GCM with a 12-byte IV encrypts; ciphertext carries a `%=` or `%$` prefix ([octagonal-wheels src/encryption/hkdf.ts](https://github.com/vrtmrz/octagonal-wheels/blob/main/src/encryption/hkdf.ts), MIT, read 2026-11-26). The PBKDF2 salt lives on the remote in `_local/obsidian_livesync_sync_parameters` ([datastructure.md](https://github.com/vrtmrz/obsidian-livesync/blob/main/docs/datastructure.md), read 2026-11-26). `read in source`
- ID key: chunk IDs and obfuscated document IDs can derive from a separate ID key (PBKDF2 of an ID source, "id-v1", xxhash64 chunk IDs) ([livesync-commonlib src/common/idDerivation.ts](https://github.com/vrtmrz/livesync-commonlib/blob/main/src/common/idDerivation.ts), read 2026-11-26); "New vaults with E2EE get a random ID key by default" ([livesync-bridge readme](https://github.com/vrtmrz/livesync-bridge/blob/main/readme.md), read 2026-11-26). `read in source`
- Format churn: the new-vault defaults are Rabin–Karp chunking, E2EE V2 and Plug-in Sync V2; Data Compression, Eden and "V1 dynamic iteration" remain readable legacy modes. From remote generation 13 the version document carries a `used_features` list, and "A client must recognise every listed feature before it interprets the database" ([LiveSync ADR: release notes and database compatibility](https://github.com/vrtmrz/obsidian-livesync/blob/main/docs/adr/2026_07_release_notes_and_database_compatibility.md), read 2026-11-26). `documented`. Unicode NFC path identity (`pathNormalizationVersion: 1`) arrived in 1.0.38–1.0.45 and needs a coordinated rebuild ([CLI README](https://github.com/vrtmrz/obsidian-livesync/blob/main/src/apps/cli/README.md), read 2026-11-26). `documented`
- Commonlib churn: eight minor releases from 0.4.0 (2026-11-07) to 0.8.0 (2026-11-26) ([livesync-commonlib releases](https://github.com/vrtmrz/livesync-commonlib/releases), MIT, read 2026-11-26). `read in source`
- Size and runtime: reimplementing chunk reassembly, E2EE V2 plus legacy modes, compression, ID derivation, obfuscation and the `used_features` gate is thousands of lines and has to track commonlib. Bash can't do it: AES-GCM decryption and PBKDF2/HKDF need a crypto library, which means Node, Deno or Python. Importing commonlib instead (MIT) means writing a thin Node app on the same core the CLI already wraps, i.e. a worse copy of option (b). `inferred`
