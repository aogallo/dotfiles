# Feature Specification: Procedure Save Dialog

**Feature Branch**: `002-procedure-save-dialog`

**Created**: 2026-09-23

**Status**: Draft

**Input**: User description: "quiero que me muestres una ventana donde me indique donde quiero guardar el procedimiento que seleccione despues de darle :dbobjects, por default dejar el root donde inicie nvim pero si quiero guardarlo en otro lugar me interesa hacerlo de nueva vez, porque si no estare con todos los sp en un solo lado"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Save a selected procedure to a chosen directory (Priority: P1)

After running `:DBObjects` and selecting a procedure, the user is asked where to save its source.
A save-location selection dialog appears, defaulting to the directory where Neovim was started.
One confirmation saves a single file containing the exact source text of the procedure.

**Why this priority**: This is the core request — the user wants the procedure text as a file they
can keep, and the location choice is the key decision point of the flow.

**Independent Test**: Can be fully tested by selecting any procedure, confirming the default
location, and verifying one file with the exact procedure source was created at the default
directory.

**Acceptance Scenarios**:

1. **Given** a procedure selected through `:DBObjects`, **When** the save dialog is shown and the
   user confirms the default, **Then** one file with the exact procedure source is created in the
   directory where Neovim was started.
2. **Given** the same selection, **When** the user instead points the dialog to a different
   directory, **Then** the file is created there, not in the default directory.
3. **Given** the dialog is cancelled, **When** no path is confirmed, **Then** no file is created,
   no directory is changed, and nothing else is altered.

---

### User Story 2 - Are asked where to save on every save (Priority: P1)

Every time the user saves a procedure, the dialog is shown again. Its default is always the
directory where Neovim was started; it never defaults to a directory the user chose in a previous
save, so procedures are not silently accumulated in one place.

**Why this priority**: The user explicitly wants to decide the location each time — the re-asking
is what prevents all stored procedures from piling up in a single folder.

**Independent Test**: Can be fully tested by saving two procedures in a row, choosing a different
directory the first time, and verifying the second dialog again defaults to the startup directory.

**Acceptance Scenarios**:

1. **Given** a procedure was previously saved to a non-default directory, **When** another
   procedure is selected and the save dialog opens, **Then** the dialog defaults to the startup
   directory again, not to the previously chosen one.
2. **Given** two consecutive selections within the same session, **When** both are saved, **Then**
   the dialog is shown in both cases (never skipped).

---

### User Story 3 - Save without collisions or data loss (Priority: P2)

Saving repeatedly never silently overwrites. If a file with the same name already exists in the
chosen directory, the user is informed and must decide explicitly. Same-named procedures from
different databases saved to the same directory stay apart because each saved file is identified by
both its owning database and its object name.

**Why this priority**: This protects the user's work and follows the repository's
non-destructive principle (no silent overwrites).

**Independent Test**: Can be fully tested by saving a procedure into a directory that already
contains a same-named file, and by saving two same-named procedures from different databases into
the same directory.

**Acceptance Scenarios**:

1. **Given** the chosen directory already contains a file with the proposed name, **When** the user
   confirms the save, **Then** the user is informed of the existing file and must explicitly choose
   to overwrite or pick a different location/name; nothing is overwritten silently.
2. **Given** two procedures with the same name in different databases, **When** both are saved to
   the same directory, **Then** two distinct files are created, one per owning database.

---

### Edge Cases

- What happens when the startup directory (Neovim launch directory) is not writable? → The save
  fails with one clear, actionable error; Neovim is not exited; the picker stays usable.
- What happens when the chosen directory does not exist? → An actionable message offers to create
  it (explicit choice) or to pick a different directory; nothing is created outside the chosen path.
- What happens on cancel (ESC / close)? → No file, no directory change, no buffer change.
- What happens when the same procedure is saved twice to the same directory? → Second save hits the
  existing-file path (US3), never a silent overwrite.
- What happens with directory/file names containing spaces or special characters? → Saved and shown
  correctly, without splitting the path.
- What happens with very large procedure text (> 255-byte lines, thousands of lines)? → The saved
  file contains the complete, byte-exact source with no mid-token wrapping or truncation.
- What happens if the selected procedure's source cannot be read (e.g., encrypted object)? → The
  existing unreadable-source notice appears and the save flow is not started; no empty file is
  created.
- Repeated runs within one session, repeated saves, existing-file conflicts, partial failures, and
  missing optional tooling (no database client) follow the non-destructive and actionable-error
  behavior described above.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: After a procedure is selected through `:DBObjects`, a save-location selection dialog
  MUST be shown so the user chooses where to save the procedure's source.
- **FR-002**: The dialog MUST default to the directory where Neovim was started (startup root) on
  every invocation, regardless of directories chosen in previous saves.
- **FR-003**: The user MUST be able to choose a different directory on each save, and the dialog
  MUST NOT remember or default to a previously chosen directory.
- **FR-004**: The user MUST be able to type an arbitrary path and to pick from known/available
  directories; both inputs resolve relative to the startup root when relative.
- **FR-005**: Confirming the save MUST produce exactly one file in the chosen directory whose
  content is the byte-exact source text of the selected procedure (no truncation, no added or
  removed characters).
- **FR-006**: The saved file MUST be identified by both its owning database and its object name, so
  same-named procedures from different databases do not collide in one directory.
- **FR-007**: If a file with the proposed name already exists in the chosen directory, the user
  MUST be informed and MUST explicitly choose whether to overwrite or change location/name; silent
  overwrites MUST NOT occur.
- **FR-008**: Cancelling the dialog at any point MUST not create files, must not change directories,
  and must not modify the state of the rest of the flow.
- **FR-009**: A failed save (unwritable target, creating a missing directory, permissions) MUST
  surface one actionable error naming the problem; Neovim MUST continue running.
- **FR-010**: The existing behavior of `:DBObjects` (listing without a name; opening the selected
  procedure's source in a buffer for editing and re-running) MUST remain available and unchanged by
  the save flow.
- **FR-011**: The defaults and behavior (startup-root default, always-ask, database-qualified
  naming) MUST be documented; no persistent user configuration is required to use the feature.
- **FR-012**: The change MUST pass headless startup, lint/format checks, and the module's existing
  smoke tests before completion.
- **FR-013**: The Neovim module README MUST document the save dialog, the startup-root default,
  always-ask behavior, naming/collision handling, personalization boundaries, validation, and
  rollback (user-managed removal of saved files).
- **FR-014**: The change MUST be scoped to the Neovim module; no other tool module may be required
  to install, update, or remove it.
- **FR-015**: Implementation MUST be developed on a feature branch with conventional commits and
  submitted through a pull request; the PR MUST verify whether the active specification (this one or
  the predecessor that provides the selection and source) is related and should be closed.
- **FR-016**: Generated task artifacts MUST link each user-story phase back to the matching heading
  in this specification and include a marker legend.

### Key Entities

- **Procedure Selection**: The object chosen in `:DBObjects`; carries the owning database, the
  object name, and its exact source text (provided by the preceding cross-database search feature).
- **Save Target Directory**: The destination of a save; defaults to the startup root and is
  overridable per save (chosen or typed path).
- **Saved Procedure File**: The single output file; identified by owning database + object name;
  contains the byte-exact source.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Selecting any readable procedure and confirming the default location saves the exact
  source within one additional action beyond the current flow (type name, select match, confirm
  location).
- **SC-002**: 100% of sequential saves default to the startup directory; a previously chosen
  directory is never proposed as default.
- **SC-003**: 100% of saves into a directory containing a same-named file require an explicit
  confirm/alter action before anything is written; zero silent overwrites.
- **SC-004**: Cancelling produces zero new or modified files in every tested case.
- **SC-005**: Same-named procedures from different databases saved to the same directory produce
  distinct files in 100% of tested cases.
- **SC-006**: Headless startup, lint/format checks, and existing module smoke tests pass; the
  module README documents the save flow, naming, validation, and rollback.

## Assumptions

- This feature builds on the cross-database object search and byte-exact source extraction provided
  by the predecessor spec `001-multidb-object-search`: a selected procedure always has an exact
  source text available. If the search/source feature is not yet merged, this Save feature's
  acceptance depends on it.
- The save dialog appears automatically as part of the selection flow after every selection (the
  user asked to be shown the save window "después de seleccionar"); the existing buffer-opening
  behavior is preserved as an additional step, not replaced.
- "Root where Neovim was started" means the working directory at Neovim launch time, captured once
  and reused as the default on every invocation — not the current buffer's directory.
- Saved file naming follows the same database-qualified convention as the object-search source
  buffers (owning database + object name) to guarantee collision-free saves (FR-006).
- The saved file contains the exact source text as-is; no batch terminator, banner, or timestamp is
  appended, and re-running semantics follow the existing execute flow.
- No configuration option to skip or disable the always-ask behavior is part of this feature; if
  the user later wants a "don't ask" mode, that is a separate feature.
- Saving is limited to readable procedures from `:DBObjects`; bulk export of many objects at once is
  out of scope.