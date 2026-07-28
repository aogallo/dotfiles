# Feature Specification: Installer Release v1

**Feature Branch**: `feat/dotfiles-installer`

**Created**: 2026-07-27

**Status**: Draft

**Input**: User description: "Ok ya hice merge del pr 49. quiero que me des el paso a paso de conversacion anterior (releases en github y v1 del installer, porque ya tengo otro cambio para el installer una mejor ux/ui). Quiero implementarlo yo. ya sea el release manual y la version automatica"

## Clarifications

### Session 2026-07-27

- Q: Should the release scope explicitly include checksums and a GitHub Actions workflow? -> A: Yes, include `checksums.txt` and a GitHub Actions release workflow.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Follow a Manual v1 Release Playbook (Priority: P1)

As the repository maintainer, I want a clear manual release playbook for publishing installer version 1 so I can create the first stable release confidently before starting the next UX/UI iteration.

**Why this priority**: This is the minimum valuable outcome. The maintainer asked to implement the steps personally and needs a safe order of operations for the first release.

**Independent Test**: Can be tested by having a maintainer follow the written playbook on a clean repository state and confirm each checkpoint is explicit before publishing.

**Acceptance Scenarios**:

1. **Given** the installer merge is present on the default branch, **When** the maintainer reads the manual release playbook, **Then** they can identify the required pre-release checks, version label, release artifacts, and publish checkpoint.
2. **Given** the maintainer has not published a previous release, **When** they follow the playbook, **Then** the process prevents accidental publication from the wrong branch or unverified state.

---

### User Story 2 - Define an Automated Release Path (Priority: P2)

As the repository maintainer, I want a GitHub Actions release workflow documented and specified so future installer releases can be published repeatably with less manual work.

**Why this priority**: Automation reduces release mistakes after the first stable version, but the manual path is still the fastest route to publishing v1.

**Independent Test**: Can be tested by reviewing the specified GitHub Actions flow and confirming it describes trigger conditions, release artifacts, checksum generation, verification gates, and failure behavior without relying on tribal knowledge.

**Acceptance Scenarios**:

1. **Given** a maintainer wants to publish a later installer version, **When** they use the GitHub Actions release workflow, **Then** the flow produces versioned installer artifacts, `checksums.txt`, and release notes.
2. **Given** required validation fails, **When** the GitHub Actions release workflow runs, **Then** no public release is completed and the maintainer receives an actionable failure summary.

---

### User Story 3 - Consume Released Installer Binaries Safely (Priority: P3)

As a dotfiles user setting up a machine, I want the bootstrap path to clearly prefer a released installer binary when requested while keeping a safe source fallback.

**Why this priority**: Released binaries improve first-run experience, but the existing source fallback already keeps setup functional.

**Independent Test**: Can be tested by reading the documented bootstrap behavior and confirming users know when a release binary is used, when fallback happens, and how integrity is verified.

**Acceptance Scenarios**:

1. **Given** a compatible release binary exists, **When** the user opts into binary preference, **Then** the bootstrap path can use the released installer and report what was selected.
2. **Given** no compatible release binary is available or verification fails, **When** the user opts into binary preference, **Then** the bootstrap path falls back safely or stops with recovery instructions.

---

### Edge Cases

- The maintainer attempts to release from a branch or commit that does not match the intended default-branch state.
- A version identifier already exists and must not be overwritten silently.
- Release artifacts are missing, incomplete, or built for the wrong macOS architecture.
- `checksums.txt` is missing, incomplete, or does not match the published artifact.
- The binary-preferred bootstrap path is requested on an unsupported platform or architecture.
- The release host is unavailable during bootstrap, requiring a clear source fallback or user-facing recovery path.
- A later installer UX/UI change is ready before v1 is published, requiring clear separation between `v1.0.0` and the next version.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The release guidance MUST define `v1.0.0` as the first stable installer release after the merged installer PR.
- **FR-002**: The manual release playbook MUST state the required clean-state, default-branch, validation, versioning, artifact, integrity, release-notes, publish, and post-publish verification checkpoints.
- **FR-003**: The manual release playbook MUST distinguish commands that only verify state from commands that publish public release state.
- **FR-004**: The release process MUST prevent accidental release creation from an unverified or unintended version identifier.
- **FR-005**: The release process MUST publish installer artifacts for supported macOS processor families or explicitly document any unsupported family before release.
- **FR-006**: The release process MUST publish `checksums.txt` with integrity records for every installer artifact.
- **FR-007**: The automated release path MUST use a GitHub Actions release workflow and define the trigger, required validations, artifact set, checksum generation, release-note source, failure behavior, and expected maintainer review point.
- **FR-008**: The automated release path MUST fail safely without publishing a completed release when validation, artifact generation, or integrity generation fails.
- **FR-009**: The bootstrap guidance MUST explain how binary preference behaves when a compatible released artifact exists, when it is missing, and when verification fails.
- **FR-010**: The release documentation MUST keep the source execution fallback visible and supported for recovery.
- **FR-011**: The release documentation MUST clarify that the next installer UX/UI work belongs to a later version unless explicitly included before `v1.0.0` is published.
- **FR-012**: Any release-related repository change MUST satisfy portability, idempotency, non-destructive behavior, dependency validation, security, verification, installer output, rollback/recovery, module README, and feature-branch/PR governance obligations.
- **FR-013**: Generated task artifacts for this feature MUST include a marker legend and link each user-story phase back to the matching heading in this specification.

### Key Entities *(include if feature involves data)*

- **Release Version**: The semantic identifier for a published installer release, including `v1.0.0` as the first stable version.
- **Release Artifact**: A downloadable installer package or executable intended for a supported macOS processor family.
- **Integrity Record**: A published checksum in `checksums.txt` that allows maintainers and users to verify artifact authenticity and completeness.
- **Release Playbook**: The maintainer-facing checklist or guide describing manual and automated release steps.
- **Bootstrap Binary Preference**: The user-facing setup choice that prefers a released installer artifact while retaining safe fallback behavior.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A maintainer can complete the documented manual v1 release path with no unstated decisions in under 15 minutes after validation passes.
- **SC-002**: 100% of published installer artifacts have matching entries in `checksums.txt` before the release is considered complete.
- **SC-003**: A reviewer can determine from documentation whether a release is manual or automated, what version is being published, and what artifacts are expected in under 5 minutes.
- **SC-004**: The automated path blocks public release completion on validation or artifact failures in every tested failure scenario.
- **SC-005**: Users choosing binary-preferred bootstrap can tell from output whether a released binary, source fallback, or recovery path was used.
- **SC-006**: The next installer UX/UI change can be planned without ambiguity about whether it belongs to `v1.0.0` or a later release.

## Assumptions

- PR #49 has been merged into the default branch before publishing `v1.0.0`.
- `v1.0.0` represents the current merged installer behavior, not the future UX/UI improvement.
- The first release may be performed manually, but the repository should specify an automated path for subsequent releases.
- The supported release target for now is macOS on Apple Silicon and Intel hardware.
- Source execution remains an accepted recovery path even when released binaries exist.
