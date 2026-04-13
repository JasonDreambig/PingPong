# PingPong

`PingPong` is a Godot 4.4 local multiplayer pong game built for desktop testing and RG35XX-style handheld controls.

## Current Source Status

The freshest ready version in this folder is the source project in the repository root:

- `main.gd`
- `menu.gd`
- `project.godot`

Those files were last updated on April 4, 2026 and are newer than the packaged export artifacts in `Exports/` and `deploy_muos/`.

## Controls

- Left paddle: `W` / `S`, D-pad, left stick
- Right paddle: arrow keys, right shoulder inputs, right stick
- Menu / back: `B`, `Menu`, or `Esc` depending on platform

## Project Files

- `menu.tscn`: title screen and score-limit selection
- `main.tscn`: game scene
- `addons/rg35xxh_exporter/`: RG35XX H export plugin files used by the project

## Notes

- Export artifacts are intentionally not tracked here because the checked-in source is newer than the last generated package.
- Rebuild a fresh handheld export from the current source before shipping to the store.
