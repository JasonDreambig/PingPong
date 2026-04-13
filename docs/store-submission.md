# Store Submission Notes

## Source Repo

- GitHub repo: `JasonDreambig/PingPong`
- Canonical branch: `main`
- SSH remote: `git@github.com:JasonDreambig/PingPong.git`

## Release Asset Plan

1. Export a fresh build from the Godot project.
2. Refresh `deploy_muos/` with the latest `PingPong.sh`, `PingPong.pck`, and `godot_runtime`.
3. Run `./scripts/package_release.sh <version>`.
4. Upload the zip from `release/github/` to GitHub Releases.
5. Use the uploaded GitHub asset URL in the RG35Go store listing.

## Suggested Store Fields

- Title: `PingPong`
- Category: `Games`
- Platform: `muOS / RG35XX`
- Source: GitHub release asset zip
- Install expectation: zip contains `PingPong.sh`, `PingPong.pck`, and `godot_runtime`

## Pre-publish Checklist

- Confirm menu and gameplay controls on device.
- Confirm the score-limit menu works.
- Confirm the build launches from muOS.
- Confirm the release zip only contains the runtime payload and not editor/build leftovers.
