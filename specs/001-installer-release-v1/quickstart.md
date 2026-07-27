# Quickstart: Validate Installer Release v1

## Prerequisites

- Work from a feature branch for implementation.
- Ensure PR #49 is merged into the default branch before publishing `v1.0.0`.
- Do not include the future installer UX/UI redesign in this release unless the spec is changed first.

## Local Validation

1. Verify repository state:

   ```sh
   git status --short
   git branch --show-current
   ```

   Expected: no unrelated changes are included in release infrastructure work.

2. Validate installer and bootstrap:

   ```sh
   (cd installer && go test ./...)
   setup/bootstrap-dotfiles-installer_test.sh
   bash -n setup/bootstrap-dotfiles-installer.sh setup/bootstrap-dotfiles-installer_test.sh
   git diff --check
   ```

   Expected: all commands pass.

## Manual v1 Release Validation

1. Confirm the intended version does not already exist:

   ```sh
   git tag --list 'v1.0.0'
   gh release view v1.0.0
   ```

   Expected: no existing tag or release for `v1.0.0`.

2. Build release artifacts from the installer module and generate `checksums.txt`.

   Expected assets are defined in [contracts/installer-release.md](./contracts/installer-release.md).

3. Before publishing, verify every binary has a matching checksum entry.

4. Publish only after validation passes and release notes clearly describe installer v1 scope.

## Automated Release Validation

1. Review `.github/workflows/release-installer.yml` before tag publication.

2. Confirm the workflow validates, builds both macOS artifacts, generates `checksums.txt`, and publishes assets only after successful checks.

3. Publish a semantic version tag from the intended default-branch commit.

4. Confirm the resulting GitHub Release contains exactly the expected assets plus release notes.

## Bootstrap Validation

1. Dry-run binary preference:

   ```sh
   setup/bootstrap-dotfiles-installer.sh --dry-run --prefer-binary
   ```

   Expected: output reports release/local binary lookup and source fallback without downloading or executing.

2. Source fallback remains available:

   ```sh
   setup/bootstrap-dotfiles-installer.sh --dry-run --no-binary
   ```

   Expected: output reports source execution path.

3. Verification failure path must not execute an unverified binary.

   Expected: bootstrap reports failed verification and uses fallback or recovery instructions.
