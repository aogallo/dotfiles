# Research: Installer Release v1

## Decision: Use a small first-party GitHub Actions workflow

**Rationale**: The repo has no existing workflows or release tooling. A focused workflow can test the installer, build `darwin/arm64` and `darwin/amd64`, generate `checksums.txt`, and publish a GitHub Release without adding a release framework dependency.

**Alternatives considered**: GoReleaser was rejected for v1 because it adds configuration surface before the repo has multiple platforms, package formats, or changelog complexity. Manual-only release was rejected as the long-term path because it increases repeat-release risk.

## Decision: Trigger automated release from semantic version tags

**Rationale**: A `v*` tag push makes the version identifier explicit and aligns the workflow with immutable release artifacts. Current GitHub Actions docs support release-oriented workflows, and tag-based release keeps the maintainer checkpoint before publication.

**Alternatives considered**: Triggering on published release was rejected because assets need to be generated before the release is complete. Manual workflow dispatch was rejected as the primary path because it allows version drift unless additional inputs are validated.

## Decision: Generate `checksums.txt` in the release workflow and require it manually

**Rationale**: Every artifact needs an integrity record before users or bootstrap automation can trust a downloaded binary. A single `checksums.txt` file keeps manual and automated verification simple.

**Alternatives considered**: Per-asset checksum files were rejected as noisier for two binaries. Skipping checksums was rejected because the spec requires verifiable binary downloads.

## Decision: Keep source fallback as the recovery path

**Rationale**: The existing bootstrap already supports `go run` fallback after prerequisites. Release binary preference should improve speed, not remove the recovery path that works when releases are unavailable or verification fails.

**Alternatives considered**: Binary-only bootstrap was rejected because release hosting/network failures would block clean-machine setup.

## Decision: Defer UX/UI redesign to a later version

**Rationale**: `v1.0.0` should represent the already-merged installer behavior. Mixing UX/UI redesign into the release infrastructure work would blur release scope and make verification harder.

**Alternatives considered**: Including UX/UI redesign before v1 was rejected because the user explicitly has another installer change planned and wants the release path first.
