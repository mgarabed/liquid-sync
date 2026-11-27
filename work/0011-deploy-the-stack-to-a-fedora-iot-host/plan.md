---
id: 0011
title: Deploy the stack to a Fedora IoT host
stage: plan
from: spec.md
---
# Plan: Deploy the stack to a Fedora IoT host

## Files that change
- `scripts/check-quadlets` (edit) — build the whole bundle, widen the `--write` guard, add the contract lint, and copy recursively before the dry-run:
  - Build the bundle in the staged `out/`: podlet output, plus `config/` and `couchdb.env.example`.
  - Widen `assert_committed` to the bundle's own file set.
  - Add the contract lint (0011 R5) and a `--lint-only <dir>` mode for the tests. That mode needs no Podman.
  - Use `cp -R` for the dry-run copy.
- `scripts/test-check-quadlets` (new) — negative tests for each lint rule, plus a pass on the committed bundle (0011 AC4). bash, no Podman needed.
- `.sdlc/config.toml` (edit) — add a `quadlet-lint-tests` verify step that runs `scripts/test-check-quadlets`. This is a control file, so the edit asks for approval.
- `deploy/quadlets/config/10-single-node.ini`, `deploy/quadlets/config/20-livesync.ini`, `deploy/quadlets/couchdb.env.example` (new) — the copies, written only by `scripts/check-quadlets --write`.
- `README.md` (edit) — the layout block: `deploy/quadlets/` holds the units plus synced copies of `config/` and the env example.
- `docs/decisions/0001-container-runtime-and-deployment.md` (edit) — dated amendment (2026-11-27, 0011) to the relative-paths compose rule: the bundle carries copies, and `check-quadlets` keeps them in sync.
- `docs/decisions/0003-host-bundle-contract.md` (edit) — dated amendment raising the Podman floor from 5.0 to 5.5, with the dry-run evidence.
- `work/0011-deploy-the-stack-to-a-fedora-iot-host/plan.md` (edit) — tick steps as they land.

## Order of work
- [ ] 1. **Bundle copies.**
  - In `check-quadlets`, after podlet runs, add `cp -R "$tmp/src/config" "$tmp/src/out/config"` and `cp "$root/couchdb.env.example" "$tmp/src/out/couchdb.env.example"`. Don't copy the staged `couchdb.env`: that's the same file under the real name, and it must not land in the bundle.
  - Widen `assert_committed`. It accepts unit files at the top level, `couchdb.env.example` at the top level, and `config/*.ini`. Anything else, or any non-regular file, still refuses the delete.
  - Change the dry-run staging to `cp -R "$committed/." "$tmp/q/"`.
  - Run `scripts/check-quadlets --write`, review the diff (only the three new files), and run `sdlc verify --fast`.
- [ ] 2. **Contract lint.** Add `lint_bundle <dir>`, which appends a `file: rule` line per violation and returns non-zero if there are any. It covers each 0011 R5 rule (a)–(j):
  - Use `find` for the file-type and extension rules.
  - Read each unit file's keys with `grep -E '^Key='`, keeping them line-anchored so comments don't match.
  - (c): exactly one `PublishPort=` line across all units, equal to `PublishPort=127.0.0.1:5984:5984`.
  - (e): `Network=` must name a `.network` file that exists in the bundle.
  - (i): `WantedBy=default.target` must sit under `[Install]`. Track the section header with awk.

  Check mode runs it on `deploy/quadlets/` and adds `lint` to `failed`. Add `--lint-only <dir>`, which runs only the lint, before the Podman availability check, and exits. Update `--help`.
- [ ] 3. **Lint tests.** `scripts/test-check-quadlets` copies `deploy/quadlets/` into a `mktemp -d` under `/tmp` (guarded like `assert_tmp`).
  - For each rule it applies one mutation, runs `scripts/check-quadlets --lint-only`, and asserts exit 1 plus the rule's message.
  - It also checks that the unmutated copy passes.
  - Add the verify step to `.sdlc/config.toml`. This needs the user's approval.
- [ ] 4. **Floor dry-run, once (0011 R6).** Pin `quay.io/podman/stable:v5.5` by digest for the record, using `podman manifest inspect` or `skopeo inspect` for the index digest. Run `quadlet -dryrun -user` on the committed bundle (expect exit 0 and no `unsupported key`), then on `v5.4` (expect `unsupported key 'Memory'`). Save both outputs for the PR and for ADR 0003. Nothing is committed in this step apart from ticking it.
- [ ] 5. **Docs.**
  - Amend ADR 0003's floor to 5.5, adding the step 4 evidence and the date. Say that the host side agreed, or that the change is pending its agreement, whichever is true at the time.
  - Amend ADR 0001's relative-paths rule.
  - Update the README layout block.
- [ ] 6. **Hand install on the Podman machine (0011 AC9),** recorded in the PR.
  - In `podman machine ssh`, as the machine's default user:
    - copy the bundle to `~/.config/containers/systemd/liquid-sync-test/`;
    - write a throwaway `couchdb.env` there with the fake example values, mode 0600;
    - run `systemctl --user daemon-reload && systemctl --user start couchdb.service`.
  - Check `curl -fsS http://127.0.0.1:5984/_up` inside the machine, then run `scripts/check-couchdb-config` with `COUCHDB_URL` pointing at the machine. If the port isn't forwarded, run the same curl calls inside the machine.
  - Record `getenforce`, `uname -m` and `podman --version`.
  - Clean up: stop the unit, remove the test directory, run `daemon-reload` again, and `podman volume rm couchdb-data`.
  - First check that the local compose stack isn't running, because both bind `127.0.0.1:5984`, and that the local stack's volume isn't the one being removed.
- [ ] 7. **Close out.** Run `sdlc verify` (full) and paste the summary line. Then run the `sdlc:verifier` agent and submit.

## Risks
- **The riskiest step is 6**, the hand install. It runs on the Podman machine, where the local dev stack also lives. A rootless quadlet `couchdb.service` would collide with the compose stack on port 5984, and `podman volume rm couchdb-data` could hit the wrong volume if the compose stack uses the same name. Mitigations:
  - Check `podman ps` and `lsof` first.
  - Compose names its volume `liquid-sync_couchdb-data` and quadlet names its own `couchdb-data`, but confirm the name with `podman volume ls` before removing anything.
  - Use only the example's fake credentials.

  If the machine is rootful and the default user's session can't run `systemctl --user`, record that and fall back to `quadlet -dryrun` plus a `podman run` that mirrors the unit's `ExecStart`. Say in the PR that this was a weaker proof.
- **Widening the `--write` guard** could let `rm -rf` delete something unexpected. The guard lists the allowed shapes explicitly (top-level unit files and `couchdb.env.example`, and `config/*.ini`) and refuses anything else, so a stray file stops the delete, as it does today.
- **The staged `couchdb.env` must not leak into the bundle.** It's a copy of the example with fake values, but step 1 copies the example by its own name only, and AC1's exact file list catches a mistake.
- **Lint false positives** once real files grow comments or new keys. Line-anchored keys and the tests keep it honest. The lint checks only what the contract states and nothing stricter.
- **The floor change needs the host side's agreement.** If the host side says no before merge, the fallback is to drop `mem_limit:` and amend ADR 0001's budget. That would be a spec change, back to the owner.
- **Rejected:**
  - Moving `config/` into the bundle and rewriting podlet's paths: it post-processes podlet output and ties the config to quadlets (intent decision).
  - A standing 5.5 dry-run in verify: the owner chose a one-time check (spec decision).
  - Folding the lint tests into `check-quadlets` itself: separate tests keep the script's normal run short and the negative cases readable.
- **Prior items:**
  - 0002 and 0008 shaped `check-quadlets`. Their guards and the narrow skip (0008 R3, R4) must survive. `--lint-only` runs before the Podman check, but only when it's asked for.
  - 0003 owns `config/*.ini` and the copying entrypoint, which stays unchanged.
- **Overlaps:** see `sdlc dep 0011 --check`. 0012 will add `deploy/hooks/` and maybe helpers in `deploy/quadlets/`. When it does, it must extend the lint and the `--write` guard's allow-list. 0011 should build first; 0012's spec will pick this up.

## Proof
- AC1: `scripts/check-quadlets --write && find deploy/quadlets -type f | sort` lists exactly the five files, and `git status --short` shows only those.
- AC2: `diff -r config deploy/quadlets/config && cmp couchdb.env.example deploy/quadlets/couchdb.env.example && podman compose config >/dev/null` exits 0.
- AC3: in `git worktree add /tmp/q11 HEAD`, apply each of the three mutations, run `scripts/check-quadlets`, and expect exit 1 with the path in the diff output. Remove the worktree afterwards.
- AC4: `scripts/test-check-quadlets` exits 0 and prints one `ok` per rule plus the clean pass.
- AC5: the two dry-run outputs from step 4, in the PR.
- AC6 and AC7: `sdlc verify` ends with `verify: PASS`. `PODMAN=/nonexistent scripts/check-quadlets --skip-if-no-podman` exits 0 with `SKIPPED`. A lint mutation with Podman reachable exits 1, which AC3's run covers with the extra-file case.
- AC8: `git grep -n -f <(grep -oE '=.+' couchdb.env.example | cut -c2-) -- deploy/` matches only `deploy/quadlets/couchdb.env.example`. Also a code read: `check-quadlets` reads only `couchdb.env.example`.
- AC9: the step 6 transcript in the PR (`_up` returns ok, no MISMATCH, plus `getenforce`, `uname -m`, `podman --version`).
- AC10: a code read of the README and the ADR 0001 and ADR 0003 diffs.
- Finally `sdlc verify`, which must end with `verify: PASS`.

## Parallel tracks
None. Steps 1–3 all edit `scripts/check-quadlets`.
