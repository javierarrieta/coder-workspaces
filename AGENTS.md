# AGENTS.md — coder-workspaces

Nix-built Coder workspace container image (`coder-workspaces-nix`). This repo
owns the image source, the build pipeline, and the GHCR publish target. The
sibling repo **`coder-templates`** consumes the image by tag string — nothing
is pushed from here into that repo.

## Repo layout (only the things you'll touch)

```
coder-workspaces/
  flake.nix               # package definition (nixos-unstable, x86_64-linux)
  image.nix               # the full image (dockerTools.buildImage, packages, FHS wiring, runAsRoot)
  README.md               # basic build/publish/consumer summary
  .github/workflows/
    ci.yml                # build verification on main/PR (nix build only, no push)
    release.yml           # semver image publishing on GitHub Release → GHCR
  docs/superpowers/       # agentic plans + specs (do not delete)
    plans/
    specs/
  coder-templates/ (OUTSIDE this repo)  # llm01-podman template + Rust provider;
                                        # pins workspace_image to a semver tag from GHCR
```

## Build the image locally

```bash
nix build .#coder-workspaces-nix
docker load -i result
```

The flake target is also exposed as `packages.x86_64-linux.default`:
```bash
nix build
```

## Publish (GitHub Actions + GHCR)

Publishing is **release-driven**, not push-driven. The workflow at
`.github/workflows/release.yml` triggers on a published GitHub Release with a
semver tag (`vMAJOR.MINOR.PATCH`), builds `.#coder-workspaces-nix`, and pushes
to the public GHCR package `ghcr.io/javierarrieta/coder-workspaces-nix`.

1. `git tag v1.2.3 && git push origin v1.2.3`
2. Create GitHub Release on that tag in the UI → publish.
3. `release.yml` runs: Nix build → `docker load -i result` → tag hierarchy → push.

### Tag strategy (updates + rollback)

A release tagged `v1.2.3` pushes these tags to GHCR:
`v1.2.3`, `1.2.3`, `v1.2`, `1.2`, `v1`, `1`, and mutable `latest`.

Rollback = pin an older release's immutable full-semver tag (e.g. `1.2.2`) in the
template. GitHub Releases history is the rollback reference. Do **not** rely on
`latest` for production workspaces.

### CI verification

`.github/workflows/ci.yml` runs `nix build .#coder-workspaces-nix` on push/PR
to `main` when `image.nix`, `flake.lock`, or `ci.yml` changes. It does **not**
publish. `release.yml` is the only workflow that pushes to GHCR.

## Relationship with coder-templates

The image and the template are coupled only by a tag string — nothing is pushed
from one repo into the other:

- **coder-workspaces** (this repo) owns the image *source* (`image.nix`) and the
  build+push pipeline. Its CI publishes to the GHCR **package**
  `ghcr.io/javierarrieta/coder-workspaces-nix`; GitHub Releases are the tag
  history / rollback reference.
- **coder-templates** only references the image by tag
  (`workspace_image = "ghcr.io/javierarrieta/coder-workspaces-nix:<tag>"` in
  `main.tf`). The workflow never writes there.

After CI publishes a new tag, the one manual hop is: pin the new immutable
semver tag into `coder-templates/templates/podman-template/main.tf`, push the
template (`coder templates push`), and **update** existing workspaces
(`coder update <workspace>`). A plain restart keeps the old image. See the
`coder-templates/AGENTS.md` for the full template push + update + restart
procedure, including the stored-parameter pitfall and the
`coder restart --parameter workspace_image=...` workaround.

## image.nix rules and constraints

### Fish override — do NOT touch

The `fish` package at the top of `image.nix` has `doCheck = false`. This
overrides the fish test suite, which fails in the container build environment
(indent/cd/path check scripts). Do **not** remove or modify this override.

```nix
fish = pkgs.fish.overrideAttrs (old: {
  doCheck = false;
});
```

### Adding or removing packages

Edit the `paths` list inside `copyToRoot = pkgs.buildEnv { ... }` in `image.nix`.
The list is grouped loosely by category (coreutils, dev, shell, python, node,
etc.). Add new packages in the appropriate group or at the end. Keep the
existing comment style for significant entries.

After editing, verify the build locally:
```bash
nix build .#coder-workspaces-nix
```

### Interactive shell handoff (bash → fish)

The image's `runAsRoot` bakes an interactive-only fish handoff into both
`/etc/bashrc` and `/etc/profile`:

```sh
if [[ $- == *i* ]] && [[ -t 0 ]] && command -v fish >/dev/null 2>&1; then
  exec fish
fi
```

The guard `[[ $- == *i* ]] && [[ -t 0 ]]` is TRUE for interactive+TTY shells and
FALSE for VS Code Remote-SSH's non-interactive piped-stdin bootstrap (which must
stay on bash). Do **not** use `[[ -o interactive ]]` — `interactive` is not a
valid `set -o` option and always evaluates false.

Verify the wiring after any change:
```bash
# non-interactive piped shell stays bash (the VS Code Remote-SSH path)
docker run --rm --entrypoint sh coder-workspaces-nix:pinned \
  -c 'echo hi | bash -c "echo running:\$0; type -t command"'   # expect: running:bash

# interactive TTY execs fish
docker run --rm -it --entrypoint bash coder-workspaces-nix:pinned -c 'echo $0'  # expect: fish
```

### FHS library wiring for VS Code Server (NixOS image)

NixOS keeps libraries in `/nix/store`, so VS Code Server's unpatched glibc
binaries can't exec. The image's `runAsRoot` wires the Nix glibc into standard
FHS paths:

- `/lib64/ld-linux-x86-64.so.2` → `${pkgs.glibc}/lib/ld-linux-x86-64.so.2`
- `libc.so.6`, `libm.so.6`, `libdl.so.2`, `libpthread.so.0`, `librt.so.1`,
  `libresolv.so.2`, `libnss_dns.so.2`, `libnss_files.so.2` → `/lib64`, `/usr/lib`, `/usr/lib64`
- `libstdc++.so.6` → `${pkgs.stdenv.cc.cc.lib}/lib/libstdc++.so.6`
- `libgcc_s.so.1` → `${pkgs.libgcc}/lib/libgcc_s.so.1`
- `libz.so.1` → `${pkgs.zlib}/lib/libz.so.1`
- `libssl.so.3` + `libcrypto.so.3` → `${pkgs.openssl}/lib/...` (in `/lib64`, `/usr/lib`, `/usr/lib64`)
- `/usr/bin/env`, `/sbin/ldconfig`, `/usr/bin/ldd`

**Do NOT drop or retarget the openssl symlinks.** VS Code's
`@vscode/vsce-sign` extension-signature verifier (`bin/vsce-sign`, a .NET
single-file binary) only dlopens libssl when it actually verifies a signature.
If the symlink is missing or dangling it SIGABRTs with
`No usable version of libssl was found`; node's `execFile` then reports a
signal kill (`error.code === null`, not numeric), which maps to
`UnknownError, Executed: false` — the misleading
"Signature verification failed with 'UnknownError'" on every extension install.
A symlink pointing at a store path outside the image closure (e.g.
`openssl-*-bin`) produces exactly this; verify with
`ls -l /lib64/libssl.so.3` inside the container (target must exist). Fake-file
smoke tests of the binary don't catch this — arg-validation errors exit before
the OpenSSL code path.

**Do NOT add a musl loader at `/lib` (`ld-musl-x86_64.so.1`).** The CLI's
`check_musl_interpreter` probe treats its presence as "musl host" and downloads
the Alpine/musl server build, whose `node` then fails with
`Error relocating ... libstdc++.so.6: symbol not found` against the glibc libs
wired above. Without it, `check_is_nixos` (`/etc/NIXOS`) + the GNU
libstdc++/libc probes select the default `server-linux-x64` build.

`touch /etc/NIXOS` is required — VS Code's CLI checks `/etc/NIXOS` (not
`os-release`) to detect NixOS and then selects the default glibc server build.

### /nix/var/nix — NOT created in runAsRoot

`runAsRoot` does **not** create `/nix/var/nix`. Re-emitting a path under the
existing `/nix` dir in `runAsRoot` produces a duplicate entry in the layer tar
and `docker load` rejects it ("duplicates of file paths not supported"). The
container's startup script (written in the template's `command`) creates
`/nix/var/nix` at runtime and `chown`s it to uid 1000.

### Container identity

The image is built with:
- `name = "coder-workspaces-nix"`; `tag = "pinned"`
- `User = "1000:1000"` (`coder` user)
- `WorkingDir = "/home/coder"`
- `Cmd = [ "/bin/sh" ]`
- `Env` includes:
  - `PATH=/home/coder/.nix-profile/bin:/bin:/usr/bin:/home/coder/.cargo/bin:/home/coder/.local/bin:/home/coder/.bun/bin`
  - `HOME=/home/coder`
  - `SHELL=/bin/bash`
  - `LD_LIBRARY_PATH=/lib64:/usr/lib64:/usr/lib`

The `runAsRoot` useradd creates uid 1000 / gid 1000 with home `/home/coder` and
shell `/bin/bash`.

## Post-publish verification

After a release is published and the template is updated:

```bash
# On the Podman host (or via coder ssh)
podman inspect coder-<workspace> --format '{{json .Config.Image}}'
podman exec coder-<workspace> ls -l /lib64/ld-linux-x86-64.so.2 /lib64/libstdc++.so.6 /lib64/libssl.so.3
podman exec coder-<workspace> command -v fish sops age kubectl terraform
```

## Tooling

- `nixfmt-tree` is the flake formatter (`nix fmt`).
- No `terraform`, `coder` CLI, or Rust toolchain is in this repo's environment.
- `docs/superpowers/` contains agentic plans and specs; preserve the directory
  structure for future agentic work.
