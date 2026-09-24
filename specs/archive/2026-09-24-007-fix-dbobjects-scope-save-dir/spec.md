# Feature Specification: Fix DBObjects Scope Feedback and Save Confirmation

**Feature Branch**: `007-fix-dbobjects-scope-save-dir`

**Created**: 2026-09-24

**Status**: Closed (archived 2026-09-24; see `verify-report.md`)

**Input**: User description: "ejecuto <leader>qo me levanta una serie de opciones 1. database: login default - change selecciono ese valor presionando enter y me da otro prompt donde ingreso el nombre de la base de datos y presiono enter y se vuelve al listado inicial y busco el sp y no aparece. escenario 2: selecciono el store procedure por default se va directo al root donde se abrio nvim. en este caso escogi la opcion 6 [type a path...] y lo guarda pero siempre me deja el inicial en el root"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Database scope stays visible and stable while browsing objects (Priority: P1)

When running the object search (`<leader>qo`), the user can choose which database the search runs in: pick an entry from the list of readable databases, or type the name of a database the list does not show. After choosing a database, the picker must stay inside that database: its header continues to show the chosen database, and searching for an object (for example a stored procedure) that exists in that database finds it. If the scope cannot be applied, the user sees a clear error and remains in the picker — the list never silently falls back to the database the user was browsing before.

**Why this priority**: The database-scope feature exists so the object search can find objects in any readable database. When the scope silently reverts or the active database is not visible, search results are wrong and the user cannot tell why. This is the primary reported defect.

**Independent Test**: Scope to a database whose name contains an underscore (for example `my_schema_db`) by typing it, then search for a stored procedure that exists only there — the procedure must appear and the picker header must show the scoped database.

**Acceptance Scenarios**:

1. **Given** an object search listing from the login-default database, **When** the user picks the "Database: … — change…" scope row, types a readable database name containing an underscore, and presses Enter, **Then** the picker reopens listing that database's objects with a header showing the scoped name and the searched stored procedure appears when narrowing.
2. **Given** a scoped object search, **When** the user picks the scope row and then cancels, **Then** the picker returns to the previous list unchanged, with the same active database as before.
3. **Given** a database name that cannot be used (unreadable, invalid characters, or equal to the current scope), **When** the user submits it, **Then** the user receives exactly one clear error message and the picker remains open showing the previous list, with the active database unchanged.
4. **Given** an object search with no database scope, **When** the user opens the picker, **Then** the header shows "login default" and the listing reflects that database.

---

### User Story 2 - Saving a stored procedure confirms where it was saved (Priority: P2)

After the user opens a stored procedure or function source, Neovim asks where to save its text. The picker starts at the directory where Neovim was opened — this is intentional and stays: it gives a general overview of the project. The user can navigate into subfolders or type a path, and the file is written exactly once to the chosen destination (never in both places). After the save completes, the user receives a notification with the full path where the file was written.

**Why this priority**: The save dialog behavior is correct, but the user cannot confirm the operation succeeded or see the destination without hunting for the file. A confirmation notification closes that gap with minimal change.

**Independent Test**: Open any stored procedure source, choose `[type a path…]`, type a destination directory, confirm; then check that a notification with the exact saved path appears and the file exists there and only there.

**Acceptance Scenarios**:

1. **Given** a stored procedure source just opened, **When** the user chooses a destination directory (by browsing or typing a path) and confirms, **Then** the file is written to that directory and the user receives a notification showing the full saved path and filename.
2. **Given** a stored procedure source just opened, **When** the user selects `[save here: <current>]` directly, **Then** the file is written to that directory (the current browse location) and the same notification appears.
3. **Given** the save picker, **When** the user navigates into subfolders before choosing a destination, **Then** only the final chosen directory receives the write; no file is created in the earlier browse locations or the startup root.
4. **Given** a target filename that already exists in the chosen directory, **When** the user confirms the save, **Then** the existing overwrite confirmation appears and the file is only replaced after explicit user choice.
5. **Given** a stored procedure source and any later save invocation in the same session, **When** the picker opens, **Then** it always starts at the directory where Neovim was opened (the general overview), regardless of where the previous file was saved.

---

### User Story 3 - The database keymap group appears in the keymap help (Priority: P3)

The database shortcuts (toggle window `<leader>qj`, UI toggle `<leader>qu`, object search `<leader>qo`, query-result summon `<leader>qr`) exist but the keymap help popup does not yet know that `<leader>q` is the "database" group, so pressing `<leader>q` alone shows no group label. Registering the group makes the which-key popup display the four database actions under a `database` heading, as the module README already documents.

**Why this priority**: This is a small, already-pending cosmetic/keymap-discoverability fix carried over from the previous feature; it does not block the other two stories but is cheap to include.

**Independent Test**: Press `<leader>q` with no trailing key — the popup must show a `database` group containing the four database actions; nothing about this story changes the other scenarios.

**Acceptance Scenarios**:

1. **Given** the keymap help popup, **When** the user presses `<leader>q`, **Then** a `database` group is shown containing the four database actions.
2. **Given** the keymap help after this change, **When** the user presses the individual database shortcuts, **Then** their behavior is unchanged.

---

### Edge Cases

- A typed database name that is equal to the current database scope — no listing refresh is performed, an actionable message explains the scope already equals the request, and the picker stays.
- A typed database name containing characters outside letters, digits, `_`, `$`, and `#` — rejected with an actionable message; the picker stays on the previous list.
- A scoped database that exists but returns no readable objects — the user is told it returned nothing and the picker remains available.
- The picked database is temporarily unreachable (connection/network failure) — a single actionable error; no fallback to any other database listing without the user's explicit choice.
- Cancelling at any point in the scope or save flow leaves the current list, active database, and any open buffers untouched (no side effects).
- Saving to a directory that does not exist yet (typed path) — the create-directory confirmation appears before writing.
- Saving with an existing same-named file — the overwrite must never happen silently.
- Repeated runs and interruptions — reopening `<leader>qo` or the save dialog repeatedly produces the same results with no accumulated state, duplicated files, or stale side effects.
- Rollback — the feature ships only as portable Neovim configuration behind a feature branch/PR; reverting the PR restores the previous behavior with no leftover user files or state.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The object search picker MUST always show the active database scope in its header, using "login default" when the connection has no selected database and the scoped name otherwise.
- **FR-002**: Choosing a database from the readable list or by typing a name MUST re-list the objects of that database and update the scope header shown by the picker.
- **FR-003**: When a database scope cannot be applied (invalid name, equal to current scope, unreadable, or empty result), the user MUST receive exactly one clear, actionable message and the picker MUST remain open on the previous list with the active scope unchanged — the scope MUST never silently revert.
- **FR-004**: A typed database name MUST accept the standard identifier characters (letters, digits, `_`, `$`, `#`); the typed name in the reported failure case (`my_schema_db`, underscore) MUST be accepted and scoped correctly.
- **FR-005**: Cancelling any scope or save dialog MUST leave the current list, active database, and buffers untouched (zero side effects).
- **FR-006**: After a successful procedure/function save, the user MUST receive a notification containing the full path and filename of the written file.
- **FR-007**: The save flow MUST write the file exactly once, to the destination confirmed by the user; navigating through earlier directories MUST NOT create files there or in the startup root.
- **FR-008**: The save dialog MUST start at the directory where Neovim was opened on every invocation, with no memory of previously chosen directories (intentional general-overview behavior).
- **FR-009**: An existing target file MUST only be replaced after an explicit overwrite confirmation, never silently.
- **FR-010**: The keymap help MUST register `<leader>q` as the `database` group listing the four database actions (`<leader>qj`, `<leader>qu`, `<leader>qo`, `<leader>qr`) without changing the actions themselves.

Constitution obligations: the change MUST stay within the Neovim module boundaries (modularity), MUST NOT introduce user-specific absolute paths or secrets (portability/security), MUST be idempotent across repeated runs, MUST include a module README update when behavior or user-facing configuration changes, and MUST be developed on a feature branch with a pull request, verifying whether the active specification should be closed at PR time.

### Key Entities *(include if feature involves data)*

- **Database scope**: the database the object search runs in; either "login default" (no database in the connection) or a chosen database name; shown in the picker header and threaded through object listing and source load.
- **Connection**: the resolved database connection URL carrying host/auth/current database; the scope is applied by rebuilding this URL with the chosen database as its path, preserving everything else.
- **Object**: a table, view, procedure, or function listed by the search; owned by one database; described by name and kind.
- **Save destination**: the directory confirmed in the save dialog; chosen by browsing ("save here"), navigating into subfolders, or typing a path, and resolved relative to the startup root when relative.
- **Saved procedure file**: the on-disk file named per the owning database and object name, written exactly once to the confirmed destination.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In 100% of attempts with a valid, readable database name (including names containing `_`), the object search lands in that database and finds an object that exists there.
- **SC-002**: Zero silent database-scope reverts: every failure to apply a scope produces an explicit message and keeps the picker contextual, verified by the acceptance scenarios.
- **SC-003**: 100% of completed saves produce a confirmation notification with the full destination path.
- **SC-004**: Every completed save writes the file exactly once — no duplicate files appear across the startup root and the chosen destination in any session.
- **SC-005**: No regression in the existing flows from previous features (object search listing, database chooser, save dialog, overwrite guard): their acceptance behaviors remain green.

## Assumptions

- The reported failure used a database name containing only a single underscore (for example `my_schema_db`), which is already within the accepted character set; the defect is therefore the silent scope behavior / search result, not name validation. Reproduction should confirm the concrete root cause before implementation.
- Prettier/dprint and other formatting behavior are out of scope for this feature.
- No persistence of the last-used save directory is desired; the startup-root default is intentional and kept.
- The existing overwrite-confirmation and create-directory prompts from previous features remain in place.
- The database list and object queries rely on the existing Sybase client (`sqsh`/`isql`) and are unchanged; this feature does not change server-side tooling or connection handling beyond the scope behavior already shipped.

## Clarifications

### Session 2026-09-24

- Q: En el escenario 1, al typear el nombre de la BD y volver al listado, ¿viste un mensaje de error? ¿Cómo es el nombre de la BD? → A: no se mostró ningún error; el nombre usa guion bajo (`_`).
- Q: Cuando un scope falla o está por aplicarse, ¿qué comportamiento del picker se quiere? → A: mostrar el error y mantenerse en el picker (sin regresar silenciosamente al listado sin scope).
- Q: Para el diálogo de guardado, ¿qué debería recordar/arrancar la próxima vez? → A: seguir arrancando en el root del directorio (vista general) y agregar una notificación de guardado que indique dónde se guardó.
- Q: ¿Se genera duplicidad de archivos entre el root y el destino elegido? → A: no; el write debe ser único en el destino confirmado (aclarado por el usuario como expectativa).