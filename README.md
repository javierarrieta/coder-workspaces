# coder-workspaces

Nix-built Coder workspace container images.

## Current image: coder-workspaces-nix

`ghcr.io/javierarrieta/coder-workspaces-nix` — immutable tags `YYYYMMDD-<short-sha>`
plus `latest` (see IMAGE_TAGS.md).

## Build locally

    nix build .#coder-workspaces-nix

## Publish

Pushes to `main` touching `image.nix`, `flake.lock`, or
`.github/workflows/build.yml` trigger a GHCR push (GitHub Actions).

## Consume

The `coder-templates` repo's `llm01-podman` template pins `workspace_image`.
Repoint it to `ghcr.io/javierarrieta/coder-workspaces-nix:<tag>`. Cluster pulls
need the GHCR image public-readable (or `registry_auth` in the template).
