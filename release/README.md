# Release Output

This folder holds publishable zips built from `deploy_muos/`.

- `github/`: upload these files to GitHub Releases.
- `store/`: handoff copy for RG35Go store packaging or archival.

Run:

```sh
./scripts/package_release.sh
```

or provide an explicit version label:

```sh
./scripts/package_release.sh v0.1.0
```
