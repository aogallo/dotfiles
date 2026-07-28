# Data Model: Installer Release v1

## Release Version

- **Fields**: semantic version (`v1.0.0` format), source commit, publication state, release notes.
- **Validation Rules**: Version must be unique, must match the intended source commit, and must not be silently overwritten.
- **Lifecycle**: Planned -> tagged -> built -> published -> verified.

## Release Artifact

- **Fields**: filename, operating system, architecture, source commit, executable payload.
- **Validation Rules**: Must include one artifact for `darwin/arm64` and one for `darwin/amd64`, unless an unsupported target is documented before release.
- **Relationships**: Belongs to one Release Version; has one matching Integrity Record.

## Integrity Record

- **Fields**: artifact filename, checksum algorithm, checksum value.
- **Validation Rules**: Every Release Artifact must have exactly one matching entry in `checksums.txt`; mismatches block release completion or bootstrap execution.
- **Relationships**: Verifies one Release Artifact.

## Release Playbook

- **Fields**: pre-release checks, manual publish commands, automated release flow, post-publish verification, recovery notes.
- **Validation Rules**: Must distinguish read-only verification from public publishing actions.

## Bootstrap Binary Preference

- **Fields**: requested mode, detected platform, detected architecture, selected source, verification result, fallback outcome.
- **Validation Rules**: Must report whether it used a released binary, local binary, source fallback, or recovery path; must not execute a failed-verification binary.
