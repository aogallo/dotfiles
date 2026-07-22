# Feature Specification: Ghostty Configuration Module

**Feature Branch**: `main` (planning only; implementation must move to a feature branch before code changes)

**Created**: 2026-07-21

**Status**: Draft

**Input**: User description: "quiero que trabajemos en la configuracion de ghosty. Ghosty es la terminal que actualmente utilizo, por lo que puedes explorar la configuracion de ghosty y tomar como configuracion inicial la configuracion de la maquina actual. Aqui esta el issue https://github.com/aogallo/dotfiles/issues/40"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Capture Portable Ghostty Configuration (Priority: P1)

As the dotfiles owner, I want the current Ghostty setup on this machine to be inspected and converted into shared, portable configuration so the repository becomes the source of truth for terminal defaults.

**Why this priority**: The repository currently mentions Ghostty but does not manage its configuration. Capturing the current working setup is the minimum valuable outcome.

**Independent Test**: Can be tested by comparing the active local Ghostty settings with the repository-managed Ghostty module and confirming all portable settings are represented while local-only values are excluded or documented separately.

**Acceptance Scenarios**:

1. **Given** Ghostty is installed on the current Mac, **When** the setup is inventoried, **Then** the expected application location and active configuration source are documented.
2. **Given** the active Ghostty configuration contains shared preferences and possible machine-specific values, **When** portable configuration is captured, **Then** shared settings are stored in the repository and local-only values are separated from the shared source of truth.
3. **Given** the current local configuration includes font, color, background, opacity, blur, padding, resize, dimensions, and tab-location preferences, **When** the repository module is reviewed, **Then** each portable preference is either included or explicitly documented as intentionally excluded.

---

### User Story 2 - Safely Adopt Repository-Managed Ghostty Config (Priority: P2)

As the dotfiles owner, I want a safe adoption path for repository-managed Ghostty configuration so existing local settings are never lost when the module is installed or linked.

**Why this priority**: Dotfiles changes are risky when they replace user-owned files. Safety, backups, and rollback are constitutional requirements for configuration management.

**Independent Test**: Can be tested by running the documented adoption flow against a machine with existing Ghostty configuration and verifying it reports conflicts, creates a recoverable backup before replacement, and preserves a rollback path.

**Acceptance Scenarios**:

1. **Given** a local Ghostty configuration already exists, **When** the repository-managed configuration is prepared for adoption, **Then** the user is shown what would change and a backup is required before any replacement or link is created.
2. **Given** the adoption flow is run more than once, **When** the same valid state already exists, **Then** no duplicate links, backup loops, or stale generated files are created.
3. **Given** adoption cannot complete safely, **When** a conflict or partial failure occurs, **Then** the local configuration remains recoverable and the user receives actionable next steps.

---

### User Story 3 - Document Ghostty Usage and Validation (Priority: P3)

As a future maintainer, I want clear Ghostty documentation so I can install, validate, customize, back up, and roll back the module without reading implementation details.

**Why this priority**: Documentation makes the module reviewable and maintainable after the initial machine inventory is converted into repository-managed configuration.

**Independent Test**: Can be tested by following the Ghostty documentation on a clean or existing Mac and confirming it explains installation expectations, configuration ownership, validation, backup, rollback, customization, and troubleshooting.

**Acceptance Scenarios**:

1. **Given** a maintainer opens the Ghostty module documentation, **When** they read it, **Then** they can identify what is managed by the repository, what remains local, and how to validate the active setup.
2. **Given** Ghostty is missing from a machine, **When** the documentation is followed, **Then** the user understands the expected installation prerequisite and how the module behaves without blocking unrelated dotfiles modules.
3. **Given** a user wants to customize private or machine-specific Ghostty values, **When** they read the documentation, **Then** they can do so without committing secrets, host-specific paths, or local-only values.

---

### Edge Cases

- Ghostty is installed but no active configuration file exists yet.
- Ghostty is not installed, but the repository module is still present and should not block unrelated dotfiles usage.
- The active configuration contains a font, theme, or visual setting unavailable on another Mac.
- Existing local configuration differs from the repository-managed defaults.
- A previous backup exists from an earlier adoption attempt.
- The adoption flow is interrupted after backup creation but before configuration activation.
- Repeated adoption runs must converge without duplicate links, repeated backups, or unclear ownership.
- Apple Silicon and Intel Macs may have different installation paths or application discovery behavior.
- Local settings may include private, work-specific, host-specific, or display-specific values that must not become shared defaults.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The feature MUST identify whether Ghostty is installed on the current machine and document the expected installation location or absence state.
- **FR-002**: The feature MUST locate and document the active Ghostty configuration source used by the current machine.
- **FR-003**: The feature MUST inventory the current local Ghostty settings and classify each as shared portable configuration, local-only configuration, or intentionally excluded configuration.
- **FR-004**: The feature MUST create a dedicated Ghostty module that is independently understandable and does not require unrelated dotfiles modules to be installed or updated.
- **FR-005**: The feature MUST make repository-managed Ghostty configuration portable by avoiding secrets, private identifiers, host-specific paths, and values that only work on this machine unless they are clearly separated as local-only guidance.
- **FR-006**: The feature MUST preserve the repository as the shared source of truth for portable Ghostty configuration while keeping generated files, local state, and private overrides separate.
- **FR-007**: The feature MUST document how existing local Ghostty configuration is backed up before replacement, linking, or adoption.
- **FR-008**: The feature MUST document a rollback path that restores the previous local Ghostty configuration after adoption.
- **FR-009**: The feature MUST define validation steps that prove Ghostty can load the managed configuration and that expected user-facing terminal behavior is preserved.
- **FR-010**: The feature MUST define repeated-run expectations so adoption or validation can be performed multiple times without duplicated state or accumulated side effects.
- **FR-011**: The feature MUST provide clear user-facing documentation for installation expectations, configuration ownership, customization boundaries, validation, backup, rollback, and troubleshooting.
- **FR-012**: The feature MUST record the relationship to GitHub issue #40 and keep implementation work on a feature branch before code changes or pull request creation.
- **FR-013**: Before pull request creation, the feature MUST verify whether the active specification should be closed by the PR and ask the user for that closure decision.

### Key Entities

- **Ghostty Installation**: The presence, expected application location, and availability state of Ghostty on a macOS machine.
- **Active Ghostty Configuration**: The local configuration source currently used by Ghostty on this machine, including its ownership and whether it is managed by the repository.
- **Portable Ghostty Setting**: A setting suitable for shared repository management because it is reviewable, reusable, and not tied to one host or private environment.
- **Local Ghostty Override**: A private or machine-specific setting that may be useful locally but must remain outside shared configuration.
- **Backup Record**: A recoverable copy or documented recovery point for any local configuration replaced or linked during adoption.
- **Ghostty Module Documentation**: The user-facing guide that explains installation, configuration ownership, validation, backup, rollback, customization, and troubleshooting.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of settings found in the active local Ghostty configuration are either captured as portable defaults or documented as excluded/local-only with a reason.
- **SC-002**: A maintainer can determine Ghostty installation status, active configuration ownership, and next action in under 5 minutes using the repository documentation.
- **SC-003**: Adoption on a machine with existing Ghostty configuration preserves a recoverable backup before any replacement or link is activated.
- **SC-004**: Re-running the documented adoption or validation flow two consecutive times produces the same managed state without duplicate links, duplicate active configuration, or unclear ownership.
- **SC-005**: Validation confirms the managed configuration is loadable by Ghostty and preserves the intended terminal appearance for normal development use.
- **SC-006**: The Ghostty module can be reviewed independently, with no secrets, private identifiers, or host-specific paths present in shared files.
- **SC-007**: Documentation covers installation, configuration ownership, validation, backup, rollback, customization boundaries, and troubleshooting in one dedicated Ghostty guide.

## Assumptions

- Ghostty refers to Ghostty, the terminal application currently used by the repository owner.
- The current machine has Ghostty installed at `/Applications/Ghostty.app`.
- The active local Ghostty configuration discovered for this specification is `~/Library/Application Support/com.mitchellh.ghostty/config.ghostty`.
- The current local settings include `font-family = IosevkaTerm NF`, `font-size = 19`, `theme = Catppuccin Frappe`, `background = 0E1419`, `background-opacity = 0.95`, `background-blur-radius = 20`, window decoration and padding behavior, fixed window dimensions, and hidden GTK tabs.
- Font and visual preferences may be portable defaults only if the documentation states their dependency and fallback expectations.
- Future installer integration is preparation scope for this feature; a complete installer implementation may be handled separately unless planning decides it is required for safe adoption.
- The repository currently has no versioned Ghostty configuration module, so this feature creates the first shared Ghostty source of truth.
