# Feature Specification: Zsh Configuration Module

**Feature Branch**: `001-zsh-config-module`

**Created**: 2026-07-21

**Status**: Draft

**Input**: User description: "quiero que trabajemos en esta issue https://github.com/aogallo/dotfiles/issues/38. Es relacionada a la configuracion de zsh"

## Clarifications

### Session 2026-07-21

- Q: Should implementation tasks explicitly use the current machine's zsh configuration as the base? -> A: Yes, implementation must inspect the current machine's real zsh files first and use them as analysis input before creating repository-managed configuration.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Capture Portable Zsh Configuration (Priority: P1)

As the dotfiles owner, I want the current machine's zsh setup to be reviewed and separated into portable and local-only configuration so that shared shell behavior can be safely managed from the repository.

**Why this priority**: This is the foundation for every later zsh installation or linking workflow; committing shell configuration without this separation risks leaking secrets, user-specific paths, or fragile machine assumptions.

**Independent Test**: Can be fully tested by reviewing the current zsh configuration sources, confirming each relevant shell setting is either represented in the repository-managed module or explicitly documented as excluded, and confirming no private values are included.

**Acceptance Scenarios**:

1. **Given** the current machine has existing zsh configuration files, **When** the configuration is reviewed, **Then** plugins, plugin managers, shell options, aliases, exports, functions, prompt setup, and tool initialization are cataloged.
2. **Given** a shell setting contains a machine-specific path, secret, credential, private identifier, or work-only value, **When** the portable module is prepared, **Then** that setting is excluded from shared configuration and documented as local-only or private.
3. **Given** a shell setting is portable and useful across machines, **When** the zsh module is reviewed, **Then** the setting is represented in the repository-managed zsh area with enough context to understand its purpose.

---

### User Story 2 - Understand and Customize Managed Zsh Behavior (Priority: P2)

As a future user of these dotfiles, I want clear zsh documentation that explains what the repository manages, what must remain local, and how customization should be handled so that I can adopt the configuration safely.

**Why this priority**: The module is not useful if users cannot distinguish shared behavior from personal shell state or understand how to adapt it without editing unsafe values into the repository.

**Independent Test**: Can be fully tested by reading the zsh documentation and verifying that a user can identify managed files, excluded local files, required or optional dependencies, validation steps, and customization guidance without reading implementation internals.

**Acceptance Scenarios**:

1. **Given** a user opens the zsh documentation, **When** they review the managed scope, **Then** they can identify which shell behaviors are repository-managed and which remain local-only.
2. **Given** a user needs personal aliases, exports, or secrets, **When** they follow the documentation, **Then** they are directed to a local/private customization path that is not intended for repository commit.
3. **Given** a user wants to validate the zsh setup, **When** they read the documentation, **Then** they find clear checks for syntax, repeated use, missing optional dependencies, and recovery expectations.

---

### User Story 3 - Prepare Safe Future Installation (Priority: P3)

As the dotfiles owner, I want the zsh module organized so a future installer can link or install it safely with conflict detection, backups, and rollback guidance.

**Why this priority**: The current change does not need to deliver the final installer, but its structure and documentation must not create future migration or safety debt.

**Independent Test**: Can be fully tested by inspecting the module and documentation to confirm that future installation behavior has clear expectations for existing files, repeated runs, skipped dependencies, partial failures, and restoration paths.

**Acceptance Scenarios**:

1. **Given** a machine already has user-owned zsh configuration, **When** the future installer requirements are reviewed, **Then** the expected behavior is to detect conflicts and preserve recoverable backups before any replacement.
2. **Given** installation is repeated, **When** the future installer expectations are reviewed, **Then** repeated runs are expected to converge without duplicate shell entries or accumulated side effects.
3. **Given** a future installation is interrupted or fails, **When** recovery guidance is reviewed, **Then** the user can understand how managed files should be restored or removed safely.

### Edge Cases

- Existing zsh files may contain secrets, tokens, private endpoints, machine-specific paths, or work-only values that must not be committed.
- Current machine configuration may reference optional tools that are not installed on every target machine.
- Shell startup may depend on ordering between plugins, environment exports, tool initialization, and aliases.
- Repeated setup attempts must not duplicate sourced files, aliases, exports, plugin entries, or generated shell state.
- Existing user-owned configuration must not be silently overwritten by repository-managed files.
- Some local files may be absent on a clean machine and should be treated as optional unless explicitly required.
- Apple Silicon and Intel Macs may require different paths or dependency locations; shared configuration must avoid hard-coding one architecture where a portable alternative exists.
- Partial failures or interrupted setup must leave a recoverable path and enough user-facing information to know what changed.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST provide a dedicated repository area for zsh configuration that is clearly separate from unrelated tool modules.
- **FR-002**: The system MUST identify the current machine's zsh configuration sources before deciding what belongs in the repository-managed module.
- **FR-002a**: The system MUST use the current machine's existing zsh setup as the implementation baseline, including `~/.zshrc`, `~/.zshenv`, `~/.zprofile`, `~/.zlogin`, `~/.zlogout`, `~/.p10k.zsh`, and any sourced zsh files when present.
- **FR-003**: The system MUST catalog relevant shell behavior, including plugins, plugin managers, shell options, aliases, exports, functions, prompt setup, and tool initialization.
- **FR-004**: The system MUST separate portable shared configuration from machine-specific, work-specific, private, generated, or secret values.
- **FR-005**: The system MUST exclude credentials, tokens, private keys, private endpoints, personal identifiers, and real local secrets from repository-managed configuration.
- **FR-006**: The system MUST avoid user-specific absolute paths in shared zsh configuration unless the path is explicitly documented as local-only and excluded from portable setup.
- **FR-007**: The system MUST document what zsh behavior is managed by the repository, what remains local-only, and how users should add personal customizations safely.
- **FR-008**: The system MUST document required and optional dependencies involved in the zsh setup, including how missing optional tools affect the user experience.
- **FR-009**: The system MUST define validation checks for the zsh configuration that cover syntax, startup safety, repeated use, missing optional tools, and conflict cases.
- **FR-010**: The system MUST preserve modularity so zsh configuration can be adopted, validated, and eventually installed without requiring unrelated dotfiles modules.
- **FR-011**: The system MUST describe safe future installation expectations, including conflict detection, backups before replacement, idempotent repeated runs, clear skipped or failed operations, and final user-facing summaries.
- **FR-012**: The system MUST include rollback or recovery guidance for restoring previous user-owned zsh configuration or removing repository-managed zsh files safely.
- **FR-013**: The system MUST support both Apple Silicon and Intel macOS environments where practical, or explicitly document any limitation.
- **FR-014**: The system MUST keep the work linked to GitHub issue #38 and follow the repository feature-branch and pull-request workflow before implementation is completed.

### Key Entities *(include if feature involves data)*

- **Zsh Configuration Module**: The repository-managed area that represents portable zsh behavior, documentation, validation expectations, and future installation boundaries.
- **Local Zsh Configuration Source**: An existing shell configuration file or sourced file on the current machine that may contain portable, local-only, generated, or private settings.
- **Portable Shell Item**: A shell option, alias, export, function, plugin declaration, prompt setting, or tool initialization that is safe and useful to share across supported machines.
- **Local-Only Shell Item**: A setting that must remain outside shared configuration because it is private, machine-specific, work-specific, generated, secret, or not generally portable.
- **Dependency Declaration**: A documented required or optional tool relationship that explains whether shell behavior depends on the dependency and how absence should be handled.
- **Recovery Guidance**: User-facing instructions that explain how to restore previous configuration, remove managed zsh setup, or recover from interrupted setup.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of identified current zsh configuration sources are either represented in the zsh module analysis or explicitly documented as excluded.
- **SC-002**: 0 known secrets, credentials, private keys, private endpoints, or real local-only personal values are included in repository-managed zsh configuration.
- **SC-003**: A reviewer can determine the managed zsh scope, local-only boundaries, dependency expectations, validation steps, and rollback path in under 10 minutes using the module documentation.
- **SC-004**: Repeated validation of the zsh setup produces no duplicate managed entries, repeated side effects, or ambiguous conflict outcomes.
- **SC-005**: The documented future installation expectations cover 100% of the required safety cases: existing configuration conflicts, backups, repeated runs, skipped optional dependencies, partial failures, and rollback.
- **SC-006**: The feature is ready for pull-request review only after it links issue #38, confirms active spec relationship, and records whether the related specification should close when the PR completes the solution.

## Assumptions

- The target user is the dotfiles owner first, with future reuse by the same user on other macOS machines.
- The feature scope is the zsh module, documentation, validation expectations, and future installer readiness; delivering the full installer is out of scope for this feature.
- Existing local zsh files on the current machine are the source of truth for analysis, but only portable and safe behavior should become repository-managed configuration.
- Local-only or private customization should remain outside committed shared files and be documented through ignored local paths, examples, or guidance.
- Missing optional tools should degrade gracefully with clear documentation rather than breaking the entire shell setup.
- Work will proceed through the repository's issue-linked feature branch and pull-request workflow rather than direct implementation commits on `main`.
