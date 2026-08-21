# coder-workspaces

Nix-built Coder workspace container images.

## Current image: coder-workspaces-nix

`ghcr.io/javierarrieta/coder-workspaces-nix` — semver tags (e.g., `v1.2.3`, `1.2.3`, `latest`) — see GitHub Releases for history.

## Build locally

    nix build .#coder-workspaces-nix

## Publish

Create a GitHub Release on a semver tag (e.g., `v1.2.3`) to publish the image
to GHCR with matching semver tags and `latest`.

## Consume

The `coder-templates` repo's `llm01-podman` template pins `workspace_image`.
Repoint it to `ghcr.io/javierarrieta/coder-workspaces-nix:<tag>`. Cluster pulls
need the GHCR image public-readable (or `registry_auth` in the template).
