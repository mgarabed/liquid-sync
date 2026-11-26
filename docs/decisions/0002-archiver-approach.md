# 0002 — Archiver approach and E2EE key handling

Status: proposed
Date: 2026-11-26
Work item: `work/0007-spike-a-choose-the-archiver-approach-adr-0002`

## Context

Goal 2 of the [project plan](../project-plan.md) is complete, durable history:
every vault mirrored as plain Markdown in git, browsable with normal git
tools and pushed offsite. LiveSync doesn't store files in CouchDB as files. It
stores Metadata documents that list content-addressed chunks, and with E2EE on
(goal 6) the chunks are encrypted and the paths can be obfuscated. Something on
the server has to turn that back into files. That's the archiver, component 4.

Two decisions were open:

- **D1:** how the archiver is built. The plan listed (a) headless Obsidian,
  (b) an existing LiveSync bridge or CLI, and (c) a custom `_changes` reader.
  The intent for this spike added (d), LiveSync's suggested backup plugin,
  Differential ZIP Backup.
- **D2:** E2EE against the archiver. Decrypting needs the vault passphrase, so
  either the server holds it or the archive is made somewhere else.

Constraints, from [ADR 0001](0001-container-runtime-and-deployment.md) and
CLAUDE.md:

- One multi-arch (amd64 and arm64) container per service, rootless under
  Podman, expressible in `compose.yaml` that podlet converts to quadlets.
- 1 GB of memory for all liquid-sync containers together, on a 4 GB Pi 4
  shared with other services.
- Clients are sacred: the archiver only reads. It never writes to a vault's
  database.
- Boring tech: a new language or runtime needs an ADR. This is that ADR.
- Vaults are small (under 500 MB, mostly Markdown, few binaries), so plain git
  holds the archive with no LFS.
- The LiveSync version under test is 1.0.52, which 0003 confirmed against this
  CouchDB setup.

This is a research-only spike: nothing was cloned or run. Every claim in
Evidence carries a source, a read date and a label. Claims labelled
`inferred` that the decision rests on become Phase 3 gates (see
Consequences).

## Options

- **(a) Headless Obsidian** (linuxserver/obsidian with LiveSync and Obsidian
  Git in the vault).
  - Costs: a 1.2 GB arm64 image running a streamed desktop, Electron and
    Obsidian around the clock. It asks for 1 GB of shared memory, the whole
    budget, and there are reports of LiveSync in this image exhausting a Pi
    and a 2 GB VPS. The web UI has no authentication by default and gives
    passwordless `sudo`. Plugins and their settings live in the vault's
    `.obsidian/` folder, which Obsidian rewrites, so pinning them is GUI state
    to manage.
  - Gives up: the memory budget (ADR 0001 would have to be reopened), a small
    attack surface, and declarative configuration.
- **(b) The official Self-hosted LiveSync CLI** (`ghcr.io/vrtmrz/livesync-cli`).
  Other (b) candidates were weaker. LiveSync Bridge has no licence, no
  releases and no published image, and its open issues include dropped files
  and missed changes. filesystem-livesync is unmaintained. The community
  tools are single-author repos with no releases.
  - Costs: Node.js arrives inside an upstream image. The CLI replicates in
    both directions and its daemon watches the output folder, so the
    read-only guarantee has to come from outside the CLI (see Decision). It's
    young (the CLI shipped with the 1.0 line), and it has had data-loss bugs
    in its write paths (#1143, #1304, both fixed). It keeps its own PouchDB
    copy of each vault.
  - Gives up: control over release timing. It ships with the plugin, several
    releases a week.
- **(c) A custom `_changes` reader.**
  - Costs: a reimplementation of chunk reassembly, E2EE V2 and the legacy
    encryption modes, compression, ID-key derivation, path obfuscation and
    the `used_features` gate. LiveSync's own docs say the format isn't a
    stable API and that commonlib's code is the authority. Bash can't do the
    crypto, so it brings a runtime anyway. Using commonlib as a library
    instead produces a thinner, unmaintained copy of the CLI.
  - Gives up: upstream tracking. Every commonlib release (eight minors in
    November 2026) becomes ours to follow.
- **(d) Differential ZIP Backup.**
  - Costs: it runs only inside an Obsidian client, and its output is
    differential ZIPs, not Markdown in git.
  - Gives up: goal 2 as the archiver. Inside option (a) it would replace
    Obsidian Git but still produce ZIPs, and it would keep all of (a)'s costs.

### Comparison

| Option | Server-side, no client | Goal 2 output | E2EE and obfuscation | amd64 + arm64 image | Rootless, podlet | Memory vs 1 GB | Maintenance | Licence, consumed as | Pinned by | Cost of a LiveSync change |
|---|---|---|---|---|---|---|---|---|---|---|
| (a) Headless Obsidian | Yes, but runs a whole desktop app | Yes, via Obsidian Git | Yes, the plugin itself | Yes, 1218 MB arm64 | Plausible (s6, PUID) but untested | Fails: 1 GB shm asked, reports of more than 2 GB | LinuxServer weekly; Obsidian Git monthly | GPL-3.0 image scripts, Obsidian free for any use; a pulled image | Image tag plus plugin files in `.obsidian/` | Update plugin files by hand to match clients |
| (b) LiveSync CLI | Yes | Yes, with our git committer | Yes, same core as the plugin | Yes, 92 MB arm64 | Yes: a plain Node image, one process | Likely under 512 MB, plus CouchDB's mirror overhead (inferred; gate) | Plugin author, released with every plugin release | MIT; a pulled image | Exact tag plus digest, bumped by commit | None by us: same release as the plugin |
| (c) Custom reader | Yes | Yes | Only if we track commonlib | Ours to build | Yes | Smallest | Ours | MIT commonlib; vendored or reimplemented | Our code | Read and port every format change |
| (d) Differential ZIP | No: client only | No: ZIPs | Sidesteps it: works on decrypted vault | None: an Obsidian plugin | n/a | n/a on server | Plugin author, monthly | MIT; installed on clients | Plugin version on clients | None to the archive |

## Decision

### D1: the archiver

**Option (b): the official LiveSync CLI, reading a one-way mirror of each
vault database, plus a small bash git committer.**

For each vault:

1. CouchDB replicates `<vault>` to `<vault>-archive` with a continuous,
   one-way `_replicator` job. The job runs as a dedicated replicator user,
   which can read `<vault>` and write `<vault>-archive`. It doesn't use the
   admin, so the job document stored in CouchDB holds no admin credentials.
   CouchDB's replicator is the only reader of the client database.
2. The CLI runs as `daemon` against `<vault>-archive`, with an archiver user.
   `vault add` sets the mirror's `_security` so that only the archiver and
   replicator users are members, and no client user. The CLI follows the
   mirror's `_changes` feed and writes the vault as plain files into an
   output directory that nothing else writes to.
3. A bash committer container commits that directory on a debounce, then
   pushes. The git directory sits outside the vault folder
   (`git --git-dir … --work-tree …`), so git never writes into it. The two
   containers share the output directory as a named volume, mounted
   read-write in the CLI and read-only in the committer. That's not a bind
   mount, so ADR 0001's `:Z` rule (a private SELinux label, which would lock
   one of the two containers out) doesn't apply. That this works rootless
   under SELinux is `inferred`, and gated in Consequences.
4. The committer pushes to the vault's archive remote with a per-vault
   deploy key that can write only that one repository. The remote receives
   plaintext notes (see D2).

This is how the archiver keeps the "only reads" rule. The CLI has no
read-only mode: `sync` and `daemon` replicate both ways, register the node in
remote `_local` documents, and push anything its file watcher sees. Its two
reported data-loss bugs (#1143, #1304) were in those write paths. With the
mirror, the archiver's credentials can't reach a client database at all, so a
CLI bug can corrupt only the mirror and the archive. Git history undoes the
archive, and resetting the mirror (below) undoes the mirror. That isolation
is `inferred` from CouchDB's one-way replication and the CLI's credentials.
The "Clients untouched" and "Mirror reconciles" gates in Consequences test
it. The mirror costs a second copy of each vault in CouchDB, which small
vaults can afford.

The CLI still writes to the mirror: conflict merges, its node registration,
and anything its watcher or startup scan wrongly sees. One-way replication
never removes those writes, so the mirror can drift from the source. The
archiver reconciles them instead of trusting the mirror. It periodically
compares the source and the mirror (the live document IDs and their winning
revisions, ignoring `_local` documents and the CLI's own conflict-resolution
revisions on top of a source revision). If they disagree, it resets the
mirror.

**Resetting the mirror** is one procedure, used for drift, for a client
rebuild and for a lost CLI volume. It runs in this order:

1. Stop the CLI daemon first, so its file watcher can't turn the cleared
   folder into deletions.
2. Cancel the replicator job.
3. Delete `<vault>-archive`, the CLI's data volume and the output folder's
   contents.
4. Recreate the mirror with its `_security`.
5. Copy `_local/obsidian_livesync_sync_parameters`, which holds the PBKDF2
   salt and doesn't replicate, from the source.
6. Restart the job and wait until it has caught up to the source's
   `update_seq`.
7. Run `fetch --force --write-settings` into the empty folder, then start the
   daemon.

The committer then commits whatever differs, so deletes made while the
volume was gone show up as deletes. A new mirror means LiveSync's revision
numbers restart, so a client's "overwrite remote" (which recreates
`<vault>`) can't leave older, higher revisions winning in the mirror. The
archiver detects that case cheaply. It polls the source's
`_local/obsidian_livesync_sync_parameters` and its database creation
identity (the `instance_start_time`/UUID from `GET /<vault>`), and resets
on any change. This is bash and `curl` against CouchDB's HTTP API.

- Option (a) is not chosen because it can't fit the 1 GB budget, its GUI
  needs authentication and hardening of its own, and its plugin state lives
  in files Obsidian rewrites, which breaks "no pets".
- Option (c) is not chosen because it means owning a reimplementation of a
  format its author says isn't a stable API, which changes several times a
  month. The CLI is the same code, maintained by the plugin's author.
- Option (d) is not chosen because it runs only on clients and writes ZIPs, so
  it can't give server-side Markdown history in git (goal 2).

### D2: E2EE and the passphrase

**Keep E2EE on, and the server holds each vault's passphrase.**

The alternatives are worse. With E2EE off, a stolen CouchDB volume or backup
is plaintext, and goal 6 is dropped. Archiving on a client means a device
that must stay on and run Obsidian, which is option (a) or (d) in another
place.

- **Where it lives:** each vault's E2EE passphrase (and its ID key, if the
  vault has one) goes in the archiver's git-ignored `archiver.env`, mode 0600,
  next to the quadlets, with a committed `archiver.env.example`. The same
  file holds the archiver's and replicator's CouchDB passwords and the path
  to each vault's deploy key, and the example lists every one. None of them
  are ever in git or logs, and that includes the CLI's own startup output,
  which Phase 3 checks. The CLI keeps it in plaintext in `settings.json` on its data
  volume, so that volume is a secret too. It should be a rebuildable cache,
  recreated from the mirror with `fetch --force` (`inferred`). Open
  `fetch --force` issues (#1304, #1365) mean a Phase 3 gate has to prove
  that before backups exclude the volume.
- **Host compromise:** an attacker with the service user or root on the host
  already reads the plaintext archive repos, and with the passphrase also
  decrypts CouchDB and can write encrypted documents. The archiver's CouchDB
  user can't write to client databases, but `couchdb.env`'s admin can, so E2EE
  gives no protection against someone who owns the host. Holding the key
  there adds little beyond what the plaintext archive already exposes.
- **A compromised archiver image:** the CLI container is the least-trusted
  part. It's young upstream code, and it holds both the key and the
  plaintext. So it runs from an exact, digest-pinned image (see Runtime), with
  a read-only root filesystem, no added capabilities, and a network that
  reaches only CouchDB.
- **The archive remote:** the committer pushes plaintext. A remote run by a
  third party (D4 allows GitHub) can read every note, whatever E2EE does in
  CouchDB. That is accepted only if D4 picks such a remote knowingly.
  Otherwise D4 should prefer a self-hosted remote. Each vault's deploy key
  can write only its own repository, so a leaked key can't reach others.
- **Backup theft:** a stolen backup holding only the CouchDB volume reveals
  no note content, because chunks stay encrypted. Without path obfuscation,
  file paths, sizes and times are still readable. The archive repos are plaintext, so
  Phase 5's backups must be encrypted at rest. `archiver.env` stays out of
  backups, because the passphrase is in the owner's password manager (D5).
  The CLI's data volume joins it once the rebuildable-volume gate in
  Consequences passes. Until then the volume is backed up, encrypted.

### Runtime

The archiver brings **Node.js 22**, only inside the upstream image
`ghcr.io/vrtmrz/livesync-cli` (multi-arch amd64 and arm64, built on
`node:22-slim`, 92 MB compressed on arm64). We write no JavaScript and build
no image. Bash can't do the job: decrypting E2EE V2 needs PBKDF2, HKDF and
AES-GCM, and rebuilding files means LiveSync's chunk and ID rules, all of
which live in LiveSync's own TypeScript core. Running the plugin author's
image is the smallest dependency that tracks them. It's MIT-licensed,
released with every plugin release, and needs no vendoring.

The committer is bash and git in a small image, chosen in Phase 3. It's
pinned the same way as the CLI, its amd64 and arm64 manifests are checked
when it's chosen, and it holds the push key, so it gets the same hardening
as the CLI. Its network reaches only the git remote.

**Pinning, amending ADR 0001.** The CLI image is pinned to an exact version
and digest. At the time of writing that's
`ghcr.io/vrtmrz/livesync-cli:1.0.52-cli@sha256:cf9c28ca544e5e84e8825185a81032559c5503ad812c6cd66be4a714bca78a4f`.
It is not ADR 0001's major-minor tag with `podman auto-update`, and the
container gets no auto-update label. This is an explicit exception to ADR
0001's compose rule for this one image, for two reasons:

- The container holds the vault passphrase and the plaintext, so an
  automatically pulled bad or compromised release could leak both, and an
  archiver-lag check wouldn't notice.
- The CLI ships several releases a week, and its version should match the
  clients' plugin (plan §5.3).

An upgrade is a commit that changes the tag and digest, made after the
round-trip gate passes on the new version. Phase 3 records the exception in
ADR 0001's compose rules.

## Evidence

All sources were read on 2026-11-26. Labels: `documented` (the project's own docs or
README say so), `read in source` (seen in code, CI config, registry manifests
or issue threads), `inferred` (my reading, not stated anywhere).

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
- Memory: nothing documented. A Node process holding PouchDB/LevelDB for a vault under 500 MB should sit under 512 MB; CouchDB's extra load from a mirror database per vault isn't estimated. `inferred`
- Secrets on disk: the README's settings example stores `"passphrase"` in `.livesync/settings.json`, and an interrupted reconstruction record "can contain settings and credentials; protect it like the settings file" ([CLI README](https://github.com/vrtmrz/obsidian-livesync/blob/main/src/apps/cli/README.md), read 2026-11-26). `documented`
- Open issues touching data safety and storage (read 2026-11-26, `read in source`):
  - [#1143](https://github.com/vrtmrz/obsidian-livesync/issues/1143) (opened 2026-08-27, read 2026-11-26): the daemon's startup scan deleted 76 documents from CouchDB because a partially warmed file cache truncated the listing. The maintainer says the fix shipped in 1.0.29; the issue is still open. `read in source`
  - [#1304](https://github.com/vrtmrz/obsidian-livesync/issues/1304) (opened 2026-10-31, read 2026-11-26): `fetch --force` without `--write-settings` left later commands on an empty database; the daemon re-uploaded every file and local files were deleted. Fixed in 1.0.44, per the maintainer. `read in source`
  - [#835](https://github.com/vrtmrz/obsidian-livesync/issues/835) (opened 2026-03-25, read 2026-11-26): chunks reportedly not replicated on push; the reporter later corrected their own measurements. Still open. `read in source`
  - [#1365](https://github.com/vrtmrz/obsidian-livesync/issues/1365) (opened 2026-11-17, read 2026-11-26): `fetch --force` aborts on a legacy encrypted chunk document. `read in source`
  - [#1346](https://github.com/vrtmrz/obsidian-livesync/issues/1346), [#1328](https://github.com/vrtmrz/obsidian-livesync/issues/1328) (read 2026-11-26): daemon rescans and missed files in new directories. `read in source`
- Supported LiveSync versions: released in lockstep with the plugin from the same source tree and shared core (`@vrtmrz/livesync-commonlib`), so a CLI tag matches the plugin of the same number. `inferred` from the tagging above.
- Takeaway: every data-loss report above comes from the CLI *writing* (the daemon's file watcher or a rebuild). An archiver only needs remote → local. `inferred`
- `sync` calls `replicateUserInitiated` and `daemon` calls `replicateUnattended`, then restores live sync and file watching; `mirror` is the scan done during database preparation ([commands/runCommand.ts](https://github.com/vrtmrz/obsidian-livesync/blob/main/src/apps/cli/commands/runCommand.ts), read 2026-11-26). Neither has a pull-only switch. `read in source`
- Remote writes the CLI makes even when no file changes: the Milestone (`_local/obsidian_livesync_milestone`, "accepted Nodes, locking …") and Node information are `_local` documents, and "do not replicate like ordinary Metadata and Chunks"; the PBKDF2 salt is in `_local/obsidian_livesync_sync_parameters` ([datastructure.md](https://github.com/vrtmrz/obsidian-livesync/blob/main/docs/datastructure.md), read 2026-11-26). `documented`. That the CLI writes its node into the remote Milestone, as the plugin does, is `inferred` from the "not yet accepted" error in `runCommand.ts` (read 2026-11-26).
- File times: commonlib's Node storage sets file times with `utimes` ([src/platform/node/storage.ts](https://github.com/vrtmrz/livesync-commonlib/blob/main/src/platform/node/storage.ts), read 2026-11-26). `read in source`. So files the CLI writes carry the database's mtime, and the mirror scan's "storage newer" branch shouldn't fire on a folder nobody edits. `inferred`
- Path obfuscation and the ID key: the CLI's settings are commonlib's full `ObsidianLiveSyncSettings`, built from `createNewVaultSettings()` ([cliSettingsDefaults.ts](https://github.com/vrtmrz/obsidian-livesync/blob/main/src/apps/cli/cliSettingsDefaults.ts), read 2026-11-26), and a setup URI is applied with `setup`. `read in source`. That obfuscated vaults then decode correctly is `inferred` (a Phase 3 gate).
- Deletions: `mirror` "does not respect file deletions" and skips deleted and conflicted entries; `daemon` follows the `_changes` feed ([CLI README](https://github.com/vrtmrz/obsidian-livesync/blob/main/src/apps/cli/README.md), read 2026-11-26). `documented`. That `daemon` removes a file from the output folder when a client deletes it, as the plugin does, is `inferred` (a Phase 3 gate).

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

- [Skyxim/livesync-git-backup](https://github.com/Skyxim/livesync-git-backup) (read 2026-11-26): runs the LiveSync CLI daemon (from a personal fork) in compose and commits the vault folder to a bare git repo on a timer. Created and last pushed 2026-10-07, no licence, no releases, 0 stars. `read in source`. It is the same shape this ADR is weighing, but not something to depend on.
- [tgmstudios/obsidian-livesync-headless](https://github.com/tgmstudios/obsidian-livesync-headless) (read 2026-11-26): an independent Node reimplementation, bidirectional, MIT, 11 stars, no releases, last push 2026-09-29. `read in source`. A third-party reimplementation of the storage format has the costs of option (c) without our control over it.
- Other hits (`gmcouto/obsidian-livesync-headless`, `MrYadro/livesync-headless`, `atty303/obsidian-livesync-cli`, …) have 0–1 stars and no releases. Not evaluated further. `read in source` (GitHub search, read 2026-11-26)

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

### Option (d): Differential ZIP Backup

- Repo: [vrtmrz/diffzip](https://github.com/vrtmrz/diffzip), maintainer vrtmrz, MIT. Releases roughly monthly: 0.1.10 (2026-07-15) through 0.1.15 (2026-11-04). Four open issues, none about data loss ([repo](https://github.com/vrtmrz/diffzip), [releases](https://github.com/vrtmrz/diffzip/releases), [issues](https://github.com/vrtmrz/diffzip/issues), read 2026-11-26). `read in source`. The LiveSync README recommends it: "For backups, we also provide a plug-in called Differential ZIP Backup" ([LiveSync README](https://github.com/vrtmrz/obsidian-livesync/blob/main/README.md), read 2026-11-26). `documented`
- Client-only: "a vault backup plugin for Obsidian", installed from Community Plugins, run from the command palette or "Start backup at launch"; `isDesktopOnly: false`, minimum Obsidian 1.8.7 ([README](https://github.com/vrtmrz/diffzip/blob/main/README.md), [manifest.json](https://github.com/vrtmrz/diffzip/blob/main/manifest.json), read 2026-11-26). `documented`. No server or CLI component in the repo. `read in source`
- Output: per-backup ZIPs (`YYYY-M-D-SECONDS.zip`) of new, changed and deleted files plus a `backupinfo.md` table of contents, written "Inside the vault", "Anywhere (Desktop only)" or to an "S3 bucket" ([README](https://github.com/vrtmrz/diffzip/blob/main/README.md), read 2026-11-26). `documented`
- Revisions: a restore dialog picks a file's revision or a restore point in time ([README](https://github.com/vrtmrz/diffzip/blob/main/README.md), read 2026-11-26). `documented`. Revisions exist only as often as a client runs a backup, so the granularity is per backup, not per edit. `inferred`
- Encryption: "the ZIP file will be encrypted by AES-256-CBC with the passphrase", decryptable with `openssl enc -d -aes-256-cbc … -pbkdf2 -md sha256` ([README](https://github.com/vrtmrz/diffzip/blob/main/README.md), read 2026-11-26). `documented`. It works on the decrypted vault on a client, so it doesn't need the LiveSync passphrase on any server. `inferred`
- Fit against goal 2: ZIPs, not browsable Markdown in git; it needs Obsidian running to take a backup. As the archiver it fails goal 2. Inside option (a) it would replace Obsidian Git but still output ZIPs. As an independent backup it is a second, differently built copy that doesn't depend on CouchDB or the archiver. `inferred`

## Consequences

The Phase 3 archiver item must pass these gates before the archiver is
trusted. Each gate turns an `inferred` claim above into a measured one. If a
gate fails, revisit this ADR rather than working around it.

- **Round-trip with E2EE on:** fixture vault → LiveSync 1.0.52 on a client →
  CouchDB → mirror → CLI → committer → files, then a diff against the
  original. Run it with E2EE, path obfuscation and the default random ID key
  on, and include a binary, a nested folder, a non-ASCII (NFC) file name, an
  edit, a rename, a delete and a conflicted note. The delete must disappear
  from the output and the rename must leave no stale copy.
- **Clients untouched:** after the round-trip, the client database has no
  revision written by the archiver, and the archiver's CouchDB user gets 401
  or 403 on any write to it.
- **Mirror reconciles:** the reconciliation check finds no drift after the
  round-trip. A deliberately injected drift (a document deleted in the
  mirror only) is detected and repaired by a reset. The CLI connects to a
  fresh mirror holding the copied salt and no Milestone of its own, without
  a client having to accept or unlock it.
- **Client rebuild:** a client does "overwrite remote", then edits files that
  already existed. The archiver detects the new salt and database identity,
  resets the mirror, and the archive ends with the edited content, not the
  old revisions.
- **Rebuildable data volume:** with the daemon stopped, a file is deleted on
  a client while the CLI's volume is gone. A reset in the order above then
  rebuilds the volume with `fetch --force`, with E2EE on, gives the same
  output folder as the client and commits the delete. The mirror gains no
  deletions from the cleared folder. Until this passes, Phase 5 backups keep
  the volume, encrypted.
- **Chunks after Metadata:** with replication paused partway through (so
  the mirror holds a large note's Metadata before all of its chunks), the
  note appears whole in the output once replication resumes, and no
  truncated or empty version is ever committed.
- **Lag per stage:** `doctor` reports both stages:
  - the replicator job's state from `_scheduler/docs`, and the source's
    `update_seq` against the mirror's;
  - the time since the archive last changed against the time since the
    mirror last changed, and the file list from the CLI's `ls` against the
    output folder.

  A job in `error` or `crashing` state, or a missing file, fails the check.
- **Memory and disk on the Pi:** measure the CLI and committer under
  `mem_limit:` on the Pi 4 during a full first sync of the largest real
  vault, plus CouchDB's growth from the mirror databases. Everything must fit
  ADR 0001's 1 GB, or that ADR is reopened. Also measure disk per vault,
  across the source, mirror, PouchDB copy, output folder and git.
- **LiveSync pinning and the upgrade check:** the CLI runs on the exact,
  digest-pinned version matching the clients' plugin. Before clients upgrade,
  the round-trip test runs on the fixture vault against the CLI of the new
  version (plan §5.3), and the pin moves in the same commit. `doctor`
  reports the running CLI version next to the clients' versions seen in the
  Milestone.
- **Unattended start and isolation:**
  - The CLI starts from the archiver's env file with no prompts, as the
    rootless service user, from podlet-generated quadlets.
  - The shared output volume works rootless under SELinux, read-write in the
    CLI and read-only in the committer.
  - Both containers run with read-only root filesystems, no added
    capabilities, and networks limited to CouchDB (CLI) and the git remote
    (committer).
  - No secret appears in either container's logs.
  - Nothing in a GUI or on the host is hand-edited.
- **Least privilege:** the archiver user gets 401 or 403 on any access to
  `<vault>`, and no client user can read or write `<vault>-archive`.

Other consequences:

- **Differential ZIP Backup** has one role: it's recommended to Phase 5's
  `backup` item as an optional, client-side disaster-recovery backup (for
  example, the Mac backing up to an S3 bucket with its AES-256 passphrase).
  It's independent of CouchDB and the archiver. This is a recommendation, not
  a decision. The `backup` item decides whether to adopt it.
- Phase 5's backups must be encrypted at rest, since the archive repos are
  plaintext. They exclude the archiver's env file, and the CLI's data
  volume once the rebuildable-volume gate passes.
- Each vault gets a second CouchDB database, `<vault>-archive`, plus an
  archiver user that can reach only that database, a replicator user, and an
  archive repository with its own deploy key. `vault add` and `vault remove`
  manage all of them, and so does `doctor`'s per-vault check.
- The committer ignores files that may hold tokens, such as
  `.obsidian/plugins/*/data.json`, by default, because the archive is
  plaintext and pushed offsite. Phase 3 decides whether the rest of
  `.obsidian` is archived.
- The committer may commit a state the CLI is partway through writing. The
  next commit repairs it, and git history keeps both. Phase 3 can tighten
  this by committing only when the mirror has no backlog.
- ADR 0001's compose rules gain two exceptions for the archiver: an exact,
  digest-pinned tag with no auto-update for the CLI (and the committer), and
  a named volume shared by two containers. Phase 3 records both in ADR
  0001's checklist.
- Plan D4 (the archive remote) has to weigh that the remote sees plaintext.
- Component 4 in the project plan now reads the mirror's `_changes` feed
  through the LiveSync CLI instead of a custom reader.
- ADR 0001's budget isn't reopened yet. Whether it fits is decided by the
  memory gate above, not by the inferred estimate here.
- Revisit this ADR if the CLI is abandoned or stops releasing with the
  plugin, if it gains a supported read-only mode (the mirror could then be
  dropped), or if LiveSync's archive-relevant format moves to a separate,
  stable API.
- A wrong decision here is superseded by a new ADR, not edited.
