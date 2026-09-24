# Feature Specification: Fix Object Save Flow

**Feature Branch**: `004-fix-object-save`

**Created**: 2026-09-23

**Status**: Closed

> **Closed** (2026-09-23): the save-flow behavior this spec reviewed is delivered and exercised by
> the `002-procedure-save-dialog` + `005-database-scope` work — the dialog always fires, buffer and
> saved-file names are database-qualified, and overwrite is never silent. Marked for closure by the
> `005-database-scope` PR review; if the reopen-with-same-name defect re-appears it should be
> tracked as a new bug, not this spec.

**Input**: User description: "al buscar un objeto no me mostro donde guardar el archivo, adicional me da un erro si es un sp que ya existe, este es el error vim.schedule callback: ..../db_objects.lua:55 buffer with this name a....., y si le doy guardar me dice no file name. y al inicio del objeto me muestra #lines of text \n 62\n text" (clarificado: el diálogo de guardado no aparece nunca, ni la primera vez ni al reabrir un SP; "setear base de datos" es una feature separada).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The save-location dialog always appears after selecting a procedure (Priority: P1)

The developer selects a procedure through `:DBObjects` and expects the "Save procedure to" dialog to appear, defaulting to the directory where Neovim was started. Today the dialog never appears — neither the first time an object is opened nor when it is reopened. After this feature, the dialog is shown on every single procedure selection, in both flows, with the startup directory as the default.

**Why this priority**: The save dialog is the central promise of the predecessor save-dialog feature; a save flow whose dialog never appears makes the feature unusable. This defect, plus the errors on reopen, is the reported regression.

**Independent Test**: Can be fully tested by selecting a procedure that has never been opened (dialog must appear) and by selecting the same procedure a second time in the same session (dialog must appear again, with no error).

**Acceptance Scenarios**:

1. **Given** a procedure never opened in the session, **When** the developer selects it through `:DBObjects`, **Then** the "Save procedure to" dialog appears immediately, defaulting to the Neovim startup directory.
2. **Given** a procedure that is already open in the session, **When** the developer selects it again, **Then** the dialog appears again and no error is raised.
3. **Given** the object picker has just closed, **When** the save dialog opens right after it, **Then** the dialog is shown without being lost or silently dropped (two selection dialogs may appear in quick succession).
4. **Given** the dialog is open, **When** the developer cancels it, **Then** no file is created, no directory is changed, and the opened buffer remains usable (non-destructive).

---

### User Story 2 - Re-opening an already-open object never errors (Priority: P1)

Selecting an object that is already open in a buffer currently raises "buffer with this name already exists", which aborts the flow (the save dialog never follows, and the buffer is left unnamed). After this feature, re-selecting an already-open object is a normal action: the existing buffer is reused/focused, the save flow still runs, and no buffer-name error ever surfaces for any object type.

**Why this priority**: This error is what breaks the reopen flow end-to-end (E95 crashes the scheduled callback → no dialog → unnamed buffer → "No file name" on `:w`). Fixing it unblocks every other story.

**Independent Test**: Can be fully tested by opening the same procedure twice in a row through `:DBObjects` and asserting the second selection neither errors nor skips the save dialog.

**Acceptance Scenarios**:

1. **Given** a procedure whose source buffer is already open, **When** the developer selects it again, **Then** the existing buffer is reused (or refocused) and the save dialog appears; no "buffer with this name already exists" error is shown.
2. **Given** two stored procedures with the same name in different databases, **When** both are opened, **Then** each keeps its own database-qualified buffer and no name collision error occurs.
3. **Given** a table or view is re-selected, **When** its list buffer is already open, **Then** the same reuse behavior applies and no buffer-name error surfaces.

---

### User Story 3 - The opened buffer is a real named buffer and `:w` never says "No file name" (Priority: P1)

The procedure source opens in a buffer that currently has no file name, so saving with `:w` fails with the cryptic "E32: No file name". After this feature, the buffer is properly named, and once the dialog saves the source, the buffer is bound to that saved file so a plain `:w` updates it. If the dialog was cancelled or the source was never saved, an attempt to write the buffer produces a clear, actionable message instead of "No file name".

**Why this priority**: The user hit this immediately ("si le doy guardar me dice no file name"); a database tool whose buffers cannot be written like normal files is surprising and blocks the edit-and-keep workflow.

**Independent Test**: Can be fully tested by selecting a procedure, saving it via the dialog, then pressing `:w` in the source buffer and confirming it writes to the same file (no prompt, no error).

**Acceptance Scenarios**:

1. **Given** a procedure just saved through the dialog, **When** the developer runs `:w` in its buffer, **Then** the buffer is written to the same saved file with no "No file name" error.
2. **Given** a procedure opened but never saved (dialog cancelled), **When** the developer runs `:w` in its buffer, **Then** a clear actionable message explains the file has not been saved yet (no cryptic E32).
3. **Given** the buffer was written with `:w`, **When** the developer re-runs the save dialog later, **Then** the existing-file confirmation flow still applies (no silent overwrite).

---

### User Story 4 - The opened object shows only the real procedure text (Priority: P2)

The top of an opened object currently contains stray clipping/non-code lines (for example a "#lines of text" marker, a line count, and a column heading "text") before the actual source. After this feature, the buffer starts directly with the procedure's definition text; client banners, column headings, row counts, prompts, and blank framing lines never appear in the buffer; and the saved file is byte-identical to what the buffer displays.

**Why this priority**: Clean, faithful source is what makes the opened buffer editable and re-runnable; the stray lines look like a corrupted export and obscure the start of the definition.

**Independent Test**: Can be fully tested by opening a procedure whose raw output includes a column-heading line, a count line, and blank framing lines, and asserting the buffer contains only the definition text and the saved file matches it exactly.

**Acceptance Scenarios**:

1. **Given** a procedure whose raw source output carries a column heading (e.g., "text"), a row count, or client banner lines, **When** the developer opens it, **Then** the buffer starts directly with the first line of the definition and none of those artifact lines appear.
2. **Given** the cleaned source in the buffer, **When** the developer saves it via the dialog, **Then** the saved file is byte-identical to the buffer's displayed text (no added, removed, or truncated content).
3. **Given** genuinely empty or unreadable source (encrypted/dropped object), **When** the developer selects it, **Then** the existing actionable notice appears instead of an empty or garbled buffer, and no save dialog/file is started.

---

### Edge Cases

- **Already-open buffer (reopen)**: reuse or refocus the existing buffer; no "buffer with this name already exists"; the save dialog still appears.
- **Same-named procedures in different databases**: database-qualified buffer names and file names keep them apart; no collisions.
- **Back-to-back dialogs**: the object picker closes and the save dialog opens immediately; the save dialog is never lost or silently dropped regardless of the picker provider in use.
- **Save before any dialog save**: `:w` on a never-saved procedure buffer gives a clear actionable message, never "No file name".
- **Save after a dialog save**: `:w` targets the bound file; repeated saves follow the existing-file confirmation, never a silent overwrite.
- **Pick an encrypted/unreadable object**: actionable notice; no empty buffer, no dialog, no file.
- **Non-writable target directory**: one clear actionable error; Neovim keeps running; the picker and buffer stay usable.
- **Source lines longer than 255 bytes**: known `sp_helptext` wrapping remains a documented limitation addressed by the upstream catalog-based extraction feature; artifact stripping and display↔file byte-equality still apply here.
- **Repeated open/save cycles**: no duplicate buffers or duplicated saved files accumulate (idempotent).
- **Missing picker provider or UI failure**: the save dialog still appears through a fallback; it is never silently skipped.
- **Rollback**: reverting the Neovim-module changes restores the predecessor save-dialog behavior (buggy reopen path); no data loss.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: After a procedure is selected through `:DBObjects`, the save-location dialog MUST appear on every selection — both first open and reopen — defaulting to the directory where Neovim was started.
- **FR-002**: The save dialog MUST open reliably when it is triggered immediately after another selection dialog closes (e.g., the object picker); it MUST never be lost or silently dropped, regardless of the selection-dialog provider in use.
- **FR-003**: Selecting an object whose buffer already exists MUST NOT raise a buffer-name error; the existing buffer MUST be reused or focused and the save flow MUST still run.
- **FR-004**: No buffer-name collision error ("buffer with this name already exists") MAY surface for any object selection (procedure, function, table, or view).
- **FR-005**: Every opened object buffer MUST have a usable file name; writing it with `:w` before any dialog save MUST produce a clear actionable message, never the cryptic "No file name".
- **FR-006**: After a successful dialog save, the object buffer MUST be bound to the saved file, so a subsequent `:w` writes to that same file without further interaction.
- **FR-007**: The buffer content MUST contain only the object's definition text: no client banners, column headings, row counts, prompts, or blank framing lines at the start or end.
- **FR-008**: The file written by the dialog MUST be byte-identical to the object text displayed in the buffer (no added, removed, or altered characters).
- **FR-009**: Cancelling the dialog at any point MUST NOT create or modify any file, MUST NOT change directories, and MUST leave the opened buffer usable (non-destructive).
- **FR-010**: Same-named objects from different databases MUST NOT collide in buffer names or saved file names; the database-qualified naming convention MUST be preserved.
- **FR-011**: All other existing behaviors of `:DBObjects` (listing, opening source, executing from the buffer) MUST remain available and unchanged except for the fixed paths.
- **FR-012**: The change MUST pass headless startup, lint/format checks, and the existing database smoke tests; new smoke coverage MUST be added for the already-open buffer flow, the back-to-back dialog sequence, and artifact stripping.
- **FR-013**: The Neovim module README MUST document the corrected save-dialog behavior, buffer naming, `:w` behavior before/after save, artifact cleaning, and rollback (user-managed removal of saved files / git revert of the module changes).
- **FR-014**: The change MUST be scoped to the Neovim module; no other tool module may be required to install, update, or remove it.
- **FR-015**: Implementation MUST be developed on a feature branch with conventional commits and submitted through a pull request; the PR MUST verify whether the active specification (this one, the predecessor save-dialog spec, or the object-search spec) is related and should be closed.
- **FR-016**: Generated task artifacts MUST link each user-story phase back to the matching heading in this specification and include a marker legend.

### Key Entities *(include if feature involves data)*

- **Procedure Selection**: the object chosen in `:DBObjects`, carrying its name, kind, owning database, and raw source text.
- **Open Source Buffer**: the SQL buffer that shows the object text; named without collisions (database-qualified) and bindable to a real saved file so `:w` works.
- **Save Target Directory**: the destination of the save; defaults to the Neovim startup directory and is chosen per save through the dialog.
- **Saved Procedure File**: the single output file; identified by owning database + object name; contains the byte-exact source; offers the existing-file confirmation on collision.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The save-location dialog appears in 100% of procedure selections, both first-open and reopen, without any error message.
- **SC-002**: Zero "buffer with this name already exists" and zero "No file name" errors across all tested selection and save flows.
- **SC-003**: After a dialog save, `:w` in the object buffer updates the saved file in 100% of tested cases.
- **SC-004**: 100% of opened objects display only the definition text (no headings, counts, banners, or framing lines), and the saved file is byte-identical to the displayed text.
- **SC-005**: Cancelling the dialog modifies zero files and leaves the session unchanged in every tested case.
- **SC-006**: Headless startup, lint/format checks, and existing database smoke tests pass, plus the new smoke coverage; the module README documents the corrected behavior and rollback.

## Assumptions

- The predecessor save-dialog feature is present (per `specs/002-procedure-save-dialog`) but defective as described; this feature fixes those defects in place rather than redesigning the flow.
- "The dialog never appears" is reproduced with the repository's current selection-dialog provider (the picker override installed in the Neovim module); the fix MUST guarantee the dialog appears regardless of which provider is active.
- The buffer-name collision error and the "No file name" error are two visible symptoms of the same broken reopen path; fixing the collision fixes the unnamed-buffer symptom.
- Source text is currently obtained through the existing extraction path; the 255-byte wrapping limitation remains documented and is owned by the upstream catalog-based extraction feature (`001-multidb-object-search`, FR-013). This feature adds artifact stripping on top of the current path and guarantees buffer↔file byte-equality.
- Saved names and buffer names keep the database-qualified convention (`owning-database.object.sql`), per the predecessor specs.
- Rollback consists of removing/undoing the Neovim-module changes via git; previously saved files remain user-owned and untouched.