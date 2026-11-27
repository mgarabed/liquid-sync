# 0003 — Host bundle contract

Status: accepted
Date: 2026-11-27
Work item: `work/0016-record-the-host-bundle-contract`

## Context

ADR 0001 runs liquid-sync rootless under a dedicated service user, with its
quadlets in that user's `~/.config/containers/systemd/`. It left open how they
get there. The production host is shared with other services and set up from
a separate private repo. That side has settled on one tool that installs
every stack the same way, called "the host tool" here. This ADR records the
contract between the host tool and liquid-sync, so liquid-sync can build and
check its side before the host tool is finished.

## Decision

liquid-sync ships a **bundle** at a git tag, described by its layout alone:
no manifest, no installer, and nothing that needs root.

### Layout

- `deploy/quadlets/`: the podlet-generated quadlets plus every config file
  they mount.
  - Only `.container`, `.volume`, `.network` and `.pod` files, needing
    nothing newer than Podman 5.0.
  - Regular files only: no symlinks and no submodules.
  - The host tool installs the directory exactly as committed into the
    service user's `~/.config/containers/systemd/`, and removes files a
    new version drops.
- `deploy/hooks/post-install`, `deploy/hooks/backup` and
  `deploy/hooks/restore`: optional, and executable when present. They run
  as the service user with the installed quadlet directory as their working
  directory, so helper files go in `deploy/quadlets/`.

### Promises the quadlets keep

- **Ports:** only `PublishPort=127.0.0.1:5984:5984`. That's one web port at
  1024 or above, which the host serves as `https://liquid-sync.<tailnet>` on
  443.
- **Networking:**
  - No `PodmanArgs=`.
  - `Network=` is only the stack's own `.network` file, or none, and never
    `host`.
  - The `.network` file uses the default bridge driver: no `Driver=`,
    `NetworkInterface=` or `Options=`. `IPv6=true` is fine.
- **Env file:** `EnvironmentFile=couchdb.env`, by relative name. The bundle
  ships only `couchdb.env.example`. The host writes `couchdb.env` (owned by
  the service user, mode 0600) before any unit starts.
- **Volumes:** named volumes hold all data worth keeping, and any `.volume`
  file sets `VolumeName=`.
- **Boot:** each `.container` that should start at boot has
  `[Install] WantedBy=default.target`.
- **Images:** pinned to a tag, never `latest`.
- **Auto-update:**
  - Set `AutoUpdate=registry` directly, never the `io.containers.autoupdate`
    label through `Label=`. The host tool refuses a bundle that sets the
    label.
  - The pinned tag is one where a new image under that tag never needs a
    data migration, because auto-update restarts the unit without running
    `post-install`.
  - Each auto-updated `.container` sets `Notify=healthy` with a health
    check, so `podman auto-update` rolls back an image that comes up
    unhealthy.

### Hooks

Hooks are idempotent and non-interactive, and they exit non-zero on failure.
They get `STACK_NAME` and `STACK_URL` (`https://<name>.<tailnet>`) in their
environment, plus a working user session for `podman` and
`systemctl --user`. They only read env files. Every secret, including the
CouchDB admin password, arrives in an env file the host supplies.

- `post-install` runs on every apply, after the units are running. It waits
  for health, then applies the CouchDB config and any migration. That's
  `liquid-sync init` without env-file generation (0012). When `couchdb.env`
  already exists, init leaves it alone and never prints it. Generating env
  files from their examples stays a local-dev path.
- `backup <dir>` and `restore <dir>`: liquid-sync chooses the format
  (Phase 5).

### What the host tool provides

- A dedicated service user named after the stack (`liquid-sync`), with:
  - a home directory and a subuid/subgid range;
  - no login shell;
  - lingering and a running user manager.
- A restart of the units whenever an installed file changes.
- `podman-auto-update.timer` for the service user, enabled on apply when
  any quadlet sets `AutoUpdate=`, and disabled on removal if the host tool
  enabled it. No hook touches the timer.
- Named volumes that are kept when the stack is removed. Only an explicit
  purge deletes them.
- Publishing: the host's own `tailscale serve` publishes `svc:liquid-sync`
  and forwards it to `127.0.0.1:5984`. The stack runs no Tailscale sidecar.

## Consequences

- Once installed, the bundle must be self-contained. `couchdb.container`
  mounts `./config`, which resolves against the installed quadlet
  directory. So the CouchDB `*.ini` files must ship in
  `deploy/quadlets/config/`, and `check-quadlets` must keep them in sync
  (0011).
- `check-quadlets` gains checks for the layout and the quadlet promises, on
  top of its podlet diff and dry-run (0011).
- `couchdb.container` doesn't yet have a health check or `Notify=healthy`.
  0011 adds them. Compose has no field for `Notify=`, so the podlet diff in
  `check-quadlets` must allow for it (0011).
- `liquid-sync init` splits into two paths (0012):
  - a host path, the `post-install` hook;
  - a local-dev path, which also generates env files and starts the stack.
- 0011's end-to-end proof is a host tool that follows this contract and
  brings CouchDB up rootless on Fedora IoT (arm64, SELinux) with a throwaway
  vault. It waits for the host tool to be built.
- A change to this contract is agreed with the host side and recorded in a
  new ADR that supersedes this one.
