# CLAUDE.md

Guidance for Claude (and other AI coding agents) working in this repo.

## What this is

liquid-sync is a self-hosted sync and history system for personal Obsidian
vaults: CouchDB + the Self-hosted LiveSync plugin for live device sync, plus a
server-side archiver that turns each vault into plain Markdown in git. It runs
as containers on any Docker or Podman host. The reference low-power target is a
Raspberry Pi 4 (arm64, Fedora IoT, Podman quadlets).

Read `docs/project-plan.md` before starting work. It holds the goals, phases,
and open questions. Record significant decisions in `docs/decisions/` as short
ADRs (`NNNN-title.md`).

## Principles

- **No pets.** Every bit of host state is either declared in this repo or is
  data covered by `backup`/`restore`. If you have to SSH in and hand-edit
  something, add it to the repo instead.
- **Clients are sacred.** Never design a step that risks data loss on a user's
  device. Migrations always take a backup first and name one device as the
  source of truth.
- **Stable endpoint.** Clients point at a stable Tailscale hostname, never an IP
  or a machine name, so moving hosts doesn't require reconfiguring clients.
- **Boring tech.** Bash for the CLI, compose for orchestration, small
  single-purpose containers. Add a new language or runtime only if an ADR
  justifies it.

## Conventions

- `compose.yaml` must work with both `docker compose` and `podman compose`.
- Images must be multi-arch (amd64 + arm64). Pin image tags (e.g. `couchdb:3.5`),
  never `latest`.
- Secrets live in `.env` (git-ignored). Keep `.env.example` current with every
  new variable. Never print secrets in logs. A setup URI is a secret.
- The CLI script is `bash` with `set -euo pipefail`, passes `shellcheck`, and
  every subcommand is idempotent and supports `--help`. Prefer `--dry-run` for
  anything that changes data.
- Each vault gets its own CouchDB database and its own archive git repo.
- Commit messages: imperative mood, short subject, body explains why.

## Testing

- Bring the stack up locally with `./liquid-sync init` and test against a
  throwaway vault in `test/fixtures/`. Never test against a real vault.
- For anything touching migration or the archiver, include a round-trip test:
  vault folder → LiveSync → CouchDB → archiver → files, then diff against the
  original.

## Don't

- Don't expose CouchDB on a public interface or open router ports.
- Don't commit vault content, CouchDB data, `.env`, or generated setup URIs.
- Don't run `git` inside client vaults. History lives server-side only.
