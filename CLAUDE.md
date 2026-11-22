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
- Secrets live in per-service `*.env` files (git-ignored), e.g. `couchdb.env`.
  Keep each one's committed `*.env.example` current with every new variable.
  Never print secrets in logs. A setup URI is a secret.
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

<!-- sdlc:begin (managed by `sdlc init`; edit freely, keep the markers) -->
## Work items (sdlc)
Feature work flows through `work/<id>-<slug>/{intent,spec,plan}.md`. Run `sdlc status` to see
items. Don't write code for a work item until its plan is accepted (`status: planned` or later).
Closed items move to `work/done/` (merged) or `work/rejected/`; cite them at those paths.
If implementation departs from `plan.md`, update `plan.md` in the same commit.

## Verifying your work
- One command: `sdlc verify` (runs the steps in `.sdlc/config.toml`; must end with "verify: PASS").
- (configure steps in .sdlc/config.toml)
Use `sdlc verify --fast` while working; run a full `sdlc verify` before submitting or reporting a work item done, and paste the summary line.
If a test fails, fix the code, not the test. Never skip, delete or weaken a failing test.

## Commands for the user
When you tell the user to run a command (the next step, or a gate only they can pass), put it in its own fenced code block: one command per block, nothing else in it, and no punctuation after it, so a triple-click or the block's copy takes exactly the command. Offering more than one? Give each its own block, the recommended one first. Write the real id, not `<id>`.
- A shell command they run from the Claude prompt: `!` attached, with no space.
  ```
  !sdlc accept 0072
  ```
- A slash command, as is.
  ```
  /sdlc:plan 0068
  ```
- A command for a separate terminal (one that starts its own session): no `!`.
  ```
  sdlc start 0072 --worktree && cd .worktrees/0072 && claude "/sdlc:build 0072"
  ```

## Requirement references
A comment or test that cites a requirement or acceptance criterion names the item: `0074 R8`, `0068 AC6`. A bare `R8` belongs only in that item's own spec and plan, since an agent reading it elsewhere can't tell which spec it means.
- Tests keep their references: they tie a test to the criterion it proves.
- In code, cite a requirement only on a comment stating a constraint someone might otherwise remove (a guard, a security or gate rule, a non-obvious limit). The comment explains the constraint itself, so it reads without opening the spec. Code whose words already say what it does needs no reference.
- An item that changes behaviour a comment cites updates or removes that comment, so no comment states a rule that no longer holds.

## Things Claude gets wrong
<!-- When a mistake happens twice, add a one-line correction here (see the sdlc:lesson skill). -->
<!-- sdlc:end -->
