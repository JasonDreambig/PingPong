# Release Workflow

This project is organized around three layers:

- Source of truth: the Godot project files in the repository root.
- Generated outputs: local export artifacts in `Exports/` and `deploy_muos/`.
- Publish targets: packaged deliverables staged under `release/`.

## Recommended flow

1. Confirm the current source in the repo root is the version you want to ship.
2. Export a fresh handheld build from Godot using the `RG35XX H` preset.
3. Refresh the muOS payload in `deploy_muos/`.
4. Package release zips into `release/github/` and `release/store/`.
5. Publish the source repo to GitHub and upload the release asset zip.
6. Use the GitHub asset URL in the RG35Go store entry.

## Expected folders

- `Exports/`: throwaway local exports from Godot.
- `deploy_muos/`: the current muOS payload used to build the release zip.
- `release/github/`: finished zip intended for GitHub release upload.
- `release/store/`: finished zip intended for store ingestion or handoff.
- `docs/screenshots/`: screenshots and store art references.
