# PingPong

`PingPong` is a Godot 4.4 local multiplayer pong game built for desktop testing and RG35XX-style handheld controls.

## Current Source Status

The repository root is the source of truth for the freshest ready version:

- `main.gd`
- `menu.gd`
- `project.godot`

Those files were updated after the older generated exports in `Exports/` and `deploy_muos/`, so new release packages should always be rebuilt from the current source before publishing.

## Controls

- Left paddle: `W` / `S`, D-pad, left stick
- Right paddle: arrow keys, right shoulder inputs, right stick
- Menu / back: `B`, `Menu`, or `Esc` depending on platform

## Folder Layout

- project root: Godot source and assets
- `addons/rg35xxh_exporter/`: RG35XX H export plugin files used by the project
- `Exports/`: local Godot export output, treated as disposable build output
- `deploy_muos/`: current muOS payload staged for packaging
- `release/`: final publishable zip output
- `docs/`: release notes, screenshots, and publishing references
- `scripts/`: helper scripts for release packaging

## Release Flow

1. Confirm the source project in the repo root is ready.
2. Export a fresh handheld build from Godot with the `RG35XX H` preset.
3. Refresh `deploy_muos/` with the latest payload.
4. Run `./scripts/package_release.sh` to create publishable zip files.
5. Upload the `release/github/` zip to GitHub Releases and use that asset URL for the store.

More detail lives in `docs/release-workflow.md`.
