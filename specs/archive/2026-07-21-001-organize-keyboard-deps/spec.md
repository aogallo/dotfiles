# Feature Specification: Organize Keyboard and Optional Dependencies

**Feature Branch**: `Not created by this command`

**Created**: 2026-07-21

**Status**: Draft

**Input**: User description: "Quiero que arreglemos este problema Nota: shfmt y shellcheck siguen faltando como dependencias opcionales, no bloquean. Quiero que muevas a uan carpeta el @iris_rev__5.json archivo de configuracion de mi teclado y asi sigamos una estructura de carpetas y configuraciones"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Resolve Optional Dependency Warnings (Priority: P1)

As the dotfiles owner, I want the optional Neovim dependency warnings for shell formatting and shell diagnostics to be clearly resolved or intentionally managed, so validation output does not leave ambiguous follow-up work.

**Why this priority**: The current validation already reports these tools as non-blocking, but the repeated warning is now a requested cleanup item.

**Independent Test**: Run the Neovim dependency validation flow and confirm required dependencies still pass and the optional dependency status is clear, actionable, and aligned with the chosen repository policy.

**Acceptance Scenarios**:

1. **Given** optional shell tooling is missing, **When** the user runs dependency validation, **Then** the output clearly distinguishes optional status from blocking failures and provides the expected resolution path.
2. **Given** the user wants a fully clean local environment, **When** they follow the documented setup path, **Then** the optional shell tooling can be installed or verified without changing unrelated tools.
3. **Given** optional tools remain intentionally absent, **When** validation completes, **Then** the result remains non-blocking and explains why.

---

### User Story 2 - Organize Keyboard Configuration (Priority: P2)

As the dotfiles owner, I want the Iris keyboard configuration file moved out of the repository root into a dedicated configuration folder, so keyboard assets follow the same organized folder structure as the rest of the dotfiles.

**Why this priority**: Repository root files become hard to scan as configuration assets grow; keyboard configuration should have a clear home.

**Independent Test**: Inspect the repository root and keyboard configuration area, then confirm the Iris configuration is stored in a named folder, remains readable, and has not changed semantically.

**Acceptance Scenarios**:

1. **Given** the Iris keyboard JSON currently exists at the repository root, **When** the organization change is complete, **Then** the file is available under a keyboard-specific configuration folder and no duplicate root copy remains.
2. **Given** the file is moved, **When** the user compares its keyboard configuration content, **Then** the keymap, macros, layers, and encoder data are preserved.
3. **Given** a future keyboard configuration is added, **When** a maintainer inspects the repository, **Then** the expected folder location is discoverable from repository structure or documentation.

---

### Edge Cases

- Optional shell tools are missing on a machine where the user only wants required Neovim dependencies.
- Optional shell tools are already installed through a different supported source.
- Dependency validation is run repeatedly before and after optional tools are installed.
- The keyboard configuration move would leave a stale duplicate in the repository root.
- A reference, README, or setup note still points to the old root-level keyboard configuration path.
- The keyboard JSON content is accidentally reformatted or altered during the move.
- A future rollback needs to restore the previous file location.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The dependency validation experience MUST make the status of the optional shell formatting and shell diagnostics tools explicit and non-ambiguous.
- **FR-002**: The repository MUST provide a clear path for users who want to resolve the optional shell tooling warnings.
- **FR-003**: Missing optional shell tooling MUST remain non-blocking unless the repository policy is intentionally changed and documented.
- **FR-004**: The solution MUST preserve existing required Neovim dependency validation behavior.
- **FR-005**: The Iris keyboard configuration MUST be moved from the repository root into a dedicated keyboard configuration folder.
- **FR-006**: The moved keyboard configuration MUST preserve its existing keyboard data without semantic changes.
- **FR-007**: The repository MUST avoid leaving duplicate active copies of the Iris keyboard configuration in multiple locations.
- **FR-008**: Any repository documentation or discoverability mechanism that references keyboard configuration location MUST reflect the new folder structure.
- **FR-009**: The change MUST avoid user-specific absolute paths, secrets, or machine-specific keyboard paths.
- **FR-010**: The change MUST include validation or review evidence that dependency status and keyboard configuration organization are correct.
- **FR-011**: The solution MUST include a rollback path for returning the keyboard configuration to its prior location if needed.
- **FR-012**: Implementation work MUST happen on a feature branch and be prepared for pull-request review before merge.

### Key Entities

- **Optional Shell Tooling**: Shell formatting and diagnostics tools that improve Neovim workflows but are not required for baseline operation.
- **Iris Keyboard Configuration**: The JSON keyboard layout/configuration currently represented by `iris_rev__5.json`.
- **Keyboard Configuration Folder**: The repository location that stores keyboard-related configuration assets.
- **Dependency Validation Result**: The user-facing outcome that reports required and optional dependency status.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can determine whether optional shell tooling requires action in under 1 minute from validation output or documentation.
- **SC-002**: Required dependency validation still completes with zero required missing dependencies after the change.
- **SC-003**: The Iris keyboard configuration is discoverable in a dedicated folder without scanning unrelated root-level files.
- **SC-004**: The moved keyboard configuration preserves 100% of existing macros, layers, and encoder entries.
- **SC-005**: No active duplicate `iris_rev__5.json` remains at the repository root after the move.
- **SC-006**: A maintainer can identify the rollback path for the keyboard configuration location in under 2 minutes.

## Assumptions

- The optional shell tools should remain optional unless the user explicitly changes repository policy during planning.
- Moving the Iris keyboard configuration means relocating the existing JSON file, not redesigning the keyboard layout.
- A dedicated keyboard folder should be repository-managed and portable across machines.
- If no existing documentation references the keyboard file, a minimal discoverability note is enough.
