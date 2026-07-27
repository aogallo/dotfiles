# Contract: Installer Release v1

## Release Assets

Each completed installer release MUST expose these assets:

| Asset | Purpose |
|-------|---------|
| `dotfiles-installer-darwin-arm64` | Apple Silicon installer binary |
| `dotfiles-installer-darwin-amd64` | Intel macOS installer binary |
| `checksums.txt` | SHA-256 integrity records for every installer binary |

## Release Workflow Behavior

- Trigger: semantic version tag matching `v*`.
- Required validations before publication: installer Go tests, bootstrap shell tests, shell syntax checks, artifact build success, and checksum generation.
- Required permission: release publication may write repository contents only for creating/updating the GitHub Release and assets.
- Failure contract: if validation, build, or checksum generation fails, no completed public release is produced.

## Manual Release Playbook Behavior

- Must start from the default branch at the intended merged installer commit.
- Must verify there is no existing conflicting version tag or release.
- Must run the same local validation commands documented in quickstart before tag publication.
- Must clearly label the first stable installer release as `v1.0.0`.

## Bootstrap Binary Preference Behavior

- `--prefer-binary` may use a compatible released binary only after checksum verification passes.
- If the release binary is unavailable or fails verification, bootstrap must report the reason and either fall back to source or stop with recovery instructions.
- `--no-binary` must continue to skip binary discovery and use source execution.
- Dry-run mode must report intended binary lookup/download/fallback behavior without downloading or executing the installer.
