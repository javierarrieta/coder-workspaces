# Design: Semver Release Tagging for Coder Workspaces

## Goals

- Publish container images **only** on semver releases (no date-based tags).
- CI verifies builds on `main`/PRs without publishing.
- Release history tracked via GitHub Releases (not `IMAGE_TAGS.md`).

## Background

The current workflow (`.github/workflows/build.yml`) builds and pushes an image on every push to `main` touching `image.nix`, `flake.lock`, or the workflow file. Tags are `YYYYMMDD-<short-sha>` plus `latest`, and `IMAGE_TAGS.md` records each tag.

This design replaces that with a semver-only release model.

## Workflows

### 1. `.github/workflows/ci.yml` — Build Verification

- **Triggers:**
  - `push` on `main`
  - `pull_request` (all branches)
- **Paths:** `image.nix`, `flake.lock`, `.github/workflows/ci.yml`
- **Job `verify`:**
  1. Checkout
  2. Install Nix (same as today)
  3. `nix build .#coder-workspaces-nix`
  4. No `docker`, no GHCR push

### 2. `.github/workflows/release.yml` — Image Publishing

- **Trigger:** `release: [published]` (manual GitHub Release)
- **Paths:** `image.nix`, `flake.lock`, `.github/workflows/release.yml`
- **Permissions:**
  ```yaml
  permissions:
    contents: write
    packages: write
  ```
- **Job `release`:**
  1. Checkout with `fetch-depth: 0`
  2. Install Nix
  3. `nix build .#coder-workspaces-nix`
  4. `docker load -i result`
  5. Compute semver from `github.ref` (strip `v` and `refs/tags/`)
  6. Tag & push hierarchy: `v1.2.3`, `1.2.3`, `v1.2`, `1.2`, `v1`, `1`, `latest`
  7. GHCR login + push all tags

## Semver Tag Computation

For a Release on tag `v1.2.3`:

| Variable | Value |
|----------|-------|
| `${VERSION}` | `1.2.3` (strip leading `v`) |
| `${MAJOR}` | `1` |
| `${MINOR}` | `2` |
| `${PATCH}` | `3` |

Image tags pushed to `ghcr.io/javierarrieta/coder-workspaces-nix`:
- `v1.2.3`
- `1.2.3`
- `v1.2`
- `1.2`
- `v1`
- `1`
- `latest`

## IMAGE_TAGS.md

- **Delete** the file.
- Release history now tracked via GitHub Releases.

## README Updates

- Replace mentions of `IMAGE_TAGS.md` and the `YYYYMMDD-<sha>` scheme.
- Reference semver tags + GitHub Releases.

## Release Process (Manual)

1. `git tag v1.2.3 && git push origin v1.2.3`
2. Create GitHub Release on tag `v1.2.3` → publish.
3. `release.yml` builds & pushes image tags.

## Out of Scope

- No `release-please` automation (releases created manually in GitHub UI).
- No back-commits to `main` from the release workflow.
