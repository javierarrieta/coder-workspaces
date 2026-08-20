# Workspace image tags

Immutable tags are pushed to `ghcr.io/javierarrieta/coder-workspaces-nix` as
`YYYYMMDD-<short-sha>`; the `latest` tag points at the newest build. Tags are
never overwritten, so pinning `workspace_image` to an older row rolls back.

Note: pre-2026-08 builds lived in the `javierarrieta/nixos-configurations` repo
and were pushed to `registry.l.arrieta.eu`; those tags are orphaned here.

| tag | date | commit | changes |
|---|---|---|---|
| 20260820-0dce1a1 | 2026-08-20 | 0dce1a1c7e455bdec413b7a16a033fa1af3b34e8 | initial build |
