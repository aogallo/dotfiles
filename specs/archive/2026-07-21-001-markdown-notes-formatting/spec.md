# Feature Specification: Markdown Notes Formatting

**Feature Branch**: Not created by this command

**Created**: 2026-07-21

**Status**: Draft

**Input**: User description: "Actualmente el formateador para archivos md es prettier. El problema es de que yo abro neovim donde estan mis notas, y trabajo en esa carpeta, basicamente ahi solo hay notas y conform falla porque no encuentra prettier. Busca como lo hace la aplicacion de obsidian y que podemos implementar nosotros para un archivo o una carpeta que no tiene ninguna configuracion, o bien proponeme como deberia de tener mi carpeta de notas."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Save Markdown Notes Without Formatter Errors (Priority: P1)

As the dotfiles owner, I want to open Neovim directly inside my notes folder and save Markdown notes without formatter errors, so note-taking is not blocked by missing project tooling.

**Why this priority**: The current save flow fails when the notes folder is just a note vault and does not contain formatter configuration.

**Independent Test**: Open a Markdown note in a notes-only folder with no project configuration, save it, and confirm no formatter error appears.

**Acceptance Scenarios**:

1. **Given** a folder contains only Markdown notes and no project formatter configuration, **When** the user saves a Markdown note from Neovim, **Then** the save completes without reporting a missing Markdown formatter.
2. **Given** the same note-only folder, **When** formatting is triggered on save, **Then** the editor either skips external formatting quietly or applies a safe built-in fallback without blocking the save.
3. **Given** a normal software project with Markdown formatting configuration, **When** the user saves a Markdown file, **Then** the configured project formatting behavior still applies.

---

### User Story 2 - Keep Notes Folders Lightweight (Priority: P2)

As the dotfiles owner, I want a recommended notes-folder structure that matches Obsidian-style usage, so I do not have to turn my notes vault into a software project just to use Neovim.

**Why this priority**: Obsidian-style note folders are primarily Markdown content plus vault-local app settings; requiring project tooling in every notes folder adds noise and maintenance burden.

**Independent Test**: Review the recommendation and confirm that a notes folder can remain usable with Markdown files and vault-local settings only.

**Acceptance Scenarios**:

1. **Given** the user creates or opens an Obsidian-style notes folder, **When** they inspect the recommended structure, **Then** it does not require project package manifests or formatter dependencies for basic note editing.
2. **Given** the user wants stronger formatting consistency for a specific notes folder, **When** they choose to add local formatting configuration, **Then** the recommendation explains what changes and what remains optional.
3. **Given** the user syncs notes across machines, **When** they review the recommendation, **Then** it avoids committing secrets, machine-specific paths, or unnecessary tooling state.

---

### User Story 3 - Preserve Project Markdown Formatting (Priority: P3)

As a maintainer, I want Markdown formatting in code projects to continue working as before, so solving the notes-vault problem does not weaken project documentation formatting.

**Why this priority**: The fix must distinguish note-taking contexts from project documentation contexts instead of disabling Markdown formatting everywhere.

**Independent Test**: Save Markdown in both a notes-only folder and a project folder with formatter configuration, then confirm each context gets the right behavior.

**Acceptance Scenarios**:

1. **Given** a software project has Markdown formatter configuration, **When** a Markdown file is saved there, **Then** the configured formatter remains available.
2. **Given** a notes-only folder has no formatter configuration, **When** a Markdown file is saved there, **Then** no project formatter lookup failure interrupts editing.
3. **Given** the user intentionally disables autoformatting, **When** a Markdown file is saved, **Then** the existing global autoformat control remains respected.

---

### Edge Cases

- A Markdown file is opened outside any project root or version-controlled directory.
- A notes folder has Obsidian vault settings but no formatter configuration.
- A notes folder intentionally has formatter configuration and should use it.
- A project has formatter tooling installed globally but no local project configuration.
- The external formatter executable is missing.
- Autoformatting is globally disabled for the session.
- Formatting is manually triggered rather than triggered on save.
- The same Neovim configuration is used on multiple machines with different notes paths.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Saving Markdown files in notes-only folders MUST NOT fail or show disruptive errors because a project Markdown formatter is unavailable.
- **FR-002**: Markdown files in folders with explicit project formatting configuration MUST continue to use that configuration.
- **FR-003**: The behavior MUST distinguish notes-only contexts from project-documentation contexts using portable signals rather than a user-specific absolute path.
- **FR-004**: The solution MUST preserve the existing global autoformat enable/disable behavior.
- **FR-005**: The solution MUST preserve safe fallback behavior for filetypes without external formatters.
- **FR-006**: The user MUST receive a clear recommendation for how to structure a notes folder used by Obsidian and Neovim.
- **FR-007**: The notes-folder recommendation MUST state which local vault/application settings are normal and which project-tooling files are optional.
- **FR-008**: The solution MUST avoid requiring every notes folder to contain package manifests, formatter dependencies, or machine-specific paths.
- **FR-009**: The solution MUST be scoped to Neovim Markdown formatting behavior and related documentation, without changing unrelated language formatting.
- **FR-010**: The solution MUST be verifiable with a notes-only Markdown save scenario and a project Markdown save scenario.
- **FR-011**: The solution MUST include rollback guidance for returning to the prior Markdown formatting behavior.
- **FR-012**: Implementation work MUST happen on a feature branch and be prepared for pull-request review before merge.

### Key Entities

- **Markdown Note**: A Markdown file used primarily for personal or knowledge-management notes.
- **Notes Folder**: A folder or vault containing notes and optional application-local settings, not necessarily project tooling.
- **Project Markdown File**: A Markdown file inside a software project or documentation project with explicit formatting configuration.
- **Formatter Configuration**: Local project settings that indicate a Markdown formatter should run.
- **Formatting Decision**: The outcome that decides whether to format, skip, or fall back for a Markdown file.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can save a Markdown note in a notes-only folder with zero formatter error notifications.
- **SC-002**: A user can save a Markdown file in a configured project and observe that project formatting still applies.
- **SC-003**: A user can identify the recommended notes-folder structure in under 2 minutes from the documentation or plan output.
- **SC-004**: The implementation changes no unrelated filetype formatter behavior.
- **SC-005**: Repeated saves in a notes-only folder produce no accumulating warnings or duplicate configuration side effects.
- **SC-006**: The Neovim configuration passes startup and formatting configuration validation after the change.

## Assumptions

- The user's notes folder follows an Obsidian-style vault model: Markdown content plus optional vault-local application settings.
- A notes-only folder should not need a package manifest or formatter dependency for basic note-taking.
- Software projects with explicit Markdown formatting configuration should retain stricter formatting behavior.
- The exact implementation strategy will be chosen during planning after reviewing Conform behavior and formatter configuration signals.
