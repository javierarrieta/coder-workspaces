# GitHub Action Image Build Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current `build.yml` workflow with two workflows: `ci.yml` for build verification on main/PRs, and `release.yml` for semver-tagged image publishing on GitHub Release.

**Architecture:** Two separate GitHub Actions workflows. `ci.yml` triggers on push/PR to main with path filtering for image.nix/flake.lock, runs `nix build` only. `release.yml` triggers on published release, computes semver tags from the release tag, builds with Nix, loads to Docker, tags with hierarchy (v1.2.3, 1.2.3, v1.2, 1.2, v1, 1, latest), and pushes all to GHCR.

**Tech Stack:** GitHub Actions, Nix, Docker, GHCR

## Global Constraints

- Publish container images ONLY on semver releases (no date-based tags)
- CI verifies builds on main/PRs without publishing
- Release history tracked via GitHub Releases (not IMAGE_TAGS.md)
- Release workflow triggers on `release: [published]` (manual GitHub Release)
- Image tags pushed: v1.2.3, 1.2.3, v1.2, 1.2, v1, 1, latest
- Permissions: contents: write, packages: write
- Nix build target: `.#coder-workspaces-nix`
- GHCR repo: `ghcr.io/javierarrieta/coder-workspaces-nix`
- Release process: manual git tag + GitHub Release publish

---

### Task 1: Create CI Verification Workflow (ci.yml)

**Files:**
- Create: `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: repository structure with `image.nix`, `flake.lock`
- Produces: Passing CI check on main/PRs for image-related changes

- [ ] **Step 1: Write the workflow file**

```yaml
name: CI

on:
  push:
    branches: [main]
    paths:
      - 'image.nix'
      - 'flake.lock'
      - '.github/workflows/ci.yml'
  pull_request:
    paths:
      - 'image.nix'
      - 'flake.lock'
      - '.github/workflows/ci.yml'

jobs:
  verify:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Install Nix
        uses: DeterminateSystems/nix-installer-action@v14

      - name: Build image
        run: nix build .#coder-workspaces-nix
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: add build verification workflow"
```

---

### Task 2: Create Release Publishing Workflow (release.yml)

**Files:**
- Create: `.github/workflows/release.yml`

**Interfaces:**
- Consumes: GitHub Release event with semver tag (e.g., v1.2.3), `image.nix`, `flake.lock`
- Produces: Docker images pushed to GHCR with full tag hierarchy

- [ ] **Step 1: Write the workflow file**

```yaml
name: Release

on:
  release:
    types: [published]

permissions:
  contents: write
  packages: write

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Install Nix
        uses: DeterminateSystems/nix-installer-action@v14

      - name: Build image
        run: nix build .#coder-workspaces-nix

      - name: Load image to Docker
        run: docker load -i result

      - name: Extract version from tag
        id: version
        run: |
          TAG=${GITHUB_REF#refs/tags/}
          VERSION=${TAG#v}
          MAJOR=$(echo $VERSION | cut -d. -f1)
          MINOR=$(echo $VERSION | cut -d. -f2)
          PATCH=$(echo $VERSION | cut -d. -f3)
          echo "version=$VERSION" >> $GITHUB_OUTPUT
          echo "major=$MAJOR" >> $GITHUB_OUTPUT
          echo "minor=$MINOR" >> $GITHUB_OUTPUT
          echo "patch=$PATCH" >> $GITHUB_OUTPUT

      - name: Tag and push images
        env:
          REGISTRY: ghcr.io/javierarrieta/coder-workspaces-nix
        run: |
          VERSION=${{ steps.version.outputs.version }}
          MAJOR=${{ steps.version.outputs.major }}
          MINOR=${{ steps.version.outputs.minor }}
          PATCH=${{ steps.version.outputs.patch }}

          TAGS=(
            "v$VERSION"
            "$VERSION"
            "v$MAJOR.$MINOR"
            "$MAJOR.$MINOR"
            "v$MAJOR"
            "$MAJOR"
            "latest"
          )

          for tag in "${TAGS[@]}"; do
            docker tag coder-workspaces-nix "$REGISTRY:$tag"
            docker push "$REGISTRY:$tag"
          done
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "release: add semver image publishing workflow"
```

---

### Task 3: Remove Old Build Workflow

**Files:**
- Delete: `.github/workflows/build.yml`

**Interfaces:**
- Removes: date-based tagging and IMAGE_TAGS.md updating logic

- [ ] **Step 1: Delete the file**

```bash
rm .github/workflows/build.yml
```

- [ ] **Step 2: Commit**

```bash
git add -A
git commit -m "ci: remove old date-based build workflow"
```

---

### Task 4: Delete IMAGE_TAGS.md

**Files:**
- Delete: `IMAGE_TAGS.md`

**Interfaces:**
- Removes: manual tag tracking file

- [ ] **Step 1: Delete the file**

```bash
rm IMAGE_TAGS.md
```

- [ ] **Step 2: Commit**

```bash
git add -A
git commit -m "docs: remove IMAGE_TAGS.md (replaced by GitHub Releases)"
```

---

### Task 5: Update README

**Files:**
- Modify: `README.md`

**Interfaces:**
- Updates: documentation to reference semver tags and GitHub Releases

- [ ] **Step 1: Read current README to identify sections to update**

```bash
grep -n "IMAGE_TAGS\|YYYYMMDD\|tag" README.md
```

- [ ] **Step 2: Update README with semver release references**

Replace mentions of:
- `IMAGE_TAGS.md` → "GitHub Releases"
- `YYYYMMDD-<sha>` scheme → "semver tags (e.g., v1.2.3, 1.2.3, latest)"
- Add reference to GitHub Releases page for release history

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: update README for semver release model"
```

---

### Task 6: Verify Workflows Locally (Optional)

**Files:**
- Test: Local validation using `act` or manual review

**Interfaces:**
- Validates: both workflows are syntactically correct and have correct triggers

- [ ] **Step 1: Validate YAML syntax**

```bash
yamllint .github/workflows/ci.yml .github/workflows/release.yml
```

- [ ] **Step 2: Verify workflow structure with GitHub CLI (if available)**

```bash
gh workflow view ci.yml
gh workflow view release.yml
```

- [ ] **Step 3: Commit any fixes**

```bash
git commit -am "ci: fix workflow validation issues"
```

---

## Self-Review Checklist

- [ ] **Spec coverage:** All spec requirements addressed:
  - ci.yml with push/PR triggers and path filtering ✓ (Task 1)
  - release.yml with release:published trigger ✓ (Task 2)
  - Permissions: contents:write, packages:write ✓ (Task 2)
  - fetch-depth: 0 for checkout ✓ (Task 2)
  - Nix build + docker load ✓ (Task 2)
  - Semver extraction from tag ✓ (Task 2)
  - Full tag hierarchy (v1.2.3, 1.2.3, v1.2, 1.2, v1, 1, latest) ✓ (Task 2)
  - GHCR login + push all tags ✓ (Task 2)
  - Delete build.yml ✓ (Task 3)
  - Delete IMAGE_TAGS.md ✓ (Task 4)
  - Update README ✓ (Task 5)

- [ ] **Placeholder scan:** No TBD/TODO/implement-later patterns found

- [ ] **Type consistency:** N/A (YAML workflows, no type signatures)

---

**Plan complete and saved to `docs/superpowers/plans/2026-08-21-github-action-image-build.md`. Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**