# Feature Specification: Database Scope for Object Search

**Feature Branch**: `005-database-scope`

**Created**: 2026-09-23

**Status**: Closed (archived 2026-09-25; see [verify-report.md](./verify-report.md))

> **Closed** (2026-09-25): delivered. 22/22 tasks in [tasks.md](./tasks.md) are `[X]`; the
> database-scope control ships in `db#adapter#sybase#with_database()` +
> `nvim/lua/config/db_objects.lua`, is covered by `nvim/lua/tests/db_objects_scope_smoke.lua`, and is
> documented in `nvim/README.md`. Evidence in [verify-report.md](./verify-report.md).

**Input**: User description: "como quedo lo de los objetos porque no puedo setear alguna base de datos?" (clarificado: "setear una base de datos" significa filtrar la búsqueda de objetos por base de datos).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Choose the database the object search runs in (Priority: P1)

The developer runs `:DBObjects` and, before/while searching, chooses the target database for that search. Today the search only ever runs in the database the connection points to, so setting the database is impossible. After this feature, the search flow offers a database-scope choice (the list of databases the login can read), defaulting to the connection's current database, and the search runs inside the chosen database.

**Why this priority**: This is the reported defect — the developer cannot set a database for the object search, so objects living elsewhere are unreachable.

**Independent Test**: Can be fully tested by running `:DBObjects`, choosing a target database other than the current one, and confirming the object listing comes from that database.

**Acceptance Scenarios**:

1. **Given** a connection whose current database is A and a readable database B, **When** the developer runs `:DBObjects` and chooses B as the target database, **Then** the object listing shows objects from B only.
2. **Given** the same flow, **When** the developer keeps the default, **Then** the search behaves exactly as today (objects from the connection's current database).
3. **Given** the target database is chosen, **When** the chooser is cancelled, **Then** no search is started, no state changes, and the developer stays in the flow they were in.

---

### User Story 2 - Open and execute results in their owning database (Priority: P1)

When the chosen target database differs from the database the connection points to, opening a result still shows the right object's source and the opened buffer executes against the owning database, never the connected one. The developer can therefore inspect and re-run a procedure found in another database without switching connections.

**Why this priority**: Searching another database is only useful if the source and the execute flow target the database that actually owns the object; otherwise the database scope produces wrong runs.

**Independent Test**: Can be fully tested by searching database B from a connection to A, opening a procedure of B, and confirming its buffer executes in B (not A) and its buffer name is database-qualified.

**Acceptance Scenarios**:

1. **Given** a connection to database A and a search scoped to database B, **When** the developer opens a procedure found in B, **Then** the source shown is B's copy and executing the buffer runs against B.
2. **Given** the same setup, **When** two same-named procedures are opened from different databases, **Then** their buffer names are database-qualified and each keeps its own database binding.
3. **Given** an object opened from the scoped search, **When** it is saved, **Then** the save file name is database-qualified with the owning database.

---

### User Story 3 - Clear labels and safe failures (Priority: P2)

Every picker row shows the database that owns the object, so same-named objects are never ambiguous. Choosing a database that does not exist or that the login cannot read produces one actionable error and never an empty or wrong picker.

**Why this priority**: Correct feedback prevents the developer from thinking a search "found nothing" when it actually failed to reach a database.

**Independent Test**: Can be fully tested by choosing an unknown database name and by searching a database with zero matching objects, confirming the distinct outcomes.

**Acceptance Scenarios**:

1. **Given** a search scoped to a valid database with matches, **When** the picker opens, **Then** every row is labelled with its owning database.
2. **Given** a chosen database the login cannot access or that does not exist, **When** the search runs, **Then** exactly one actionable error naming the database appears and no picker or buffer is opened.
3. **Given** a scoped search with no matching objects, **When** it completes, **Then** a clear no-match message appears and no buffer is opened.

---

### Edge Cases

- **No database chosen (default)**: the current connection database is searched; behavior identical to today.
- **Choice cancelled**: nothing runs, nothing changes (non-destructive).
- **Unknown or inaccessible database**: one actionable error naming the database; no empty picker, no buffer.
- **Database name with special characters**: values are escaped before interpolation — never raw input.
- **Same-named objects in different databases**: rows carry their owning database; opened buffers and saved files stay database-qualified.
- **Primary target is a different database than the connection's**: source loading and execution still target the owning database.
- **Non-Sybase schemes (SQL Server, MongoDB)**: keep the current fallback behavior; the database-scope control is a Sybase-only flow.
- **Missing client / connection failure**: the existing actionable error path; no partial state.
- **Repeated runs (idempotency)**: repeated searches/scoping do not duplicate buffers or accumulate stale state.
- **Cross-database `%` search and optional team procedure**: explicitly out of scope for this feature (owned by the predecessor multi-DB spec `001-multidb-object-search`).
- **Rollback**: reverting the Neovim-module changes restores single-database behavior with no data loss.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The object-search flow MUST let the developer set the target database of a search, choosing from the databases the login can read, with the connection's current database as the default on every invocation.
- **FR-002**: The search MUST run inside the chosen target database using portable database selection (no client-specific flags), independent of the database the connection points to.
- **FR-003**: Every object row in the picker MUST display its owning database, so identical object names are never ambiguous.
- **FR-004**: Opening an object found in a database other than the connected one MUST load its source from the owning database and bind the new buffer to the owning database; executing that buffer MUST run in the owning database (never out-of-database).
- **FR-005**: Opened buffers and saved files MUST remain identified by owning database + object name (no collisions across databases).
- **FR-006**: The default behavior of the command without arguments MUST remain unchanged (listing the connected database's objects, exactly as today).
- **FR-007**: Choosing a database the login cannot access or that does not exist MUST surface exactly one actionable error naming that database, and MUST NOT open an empty picker or buffer.
- **FR-008**: Database names MUST be escaped/sanitized before interpolation into any query; never raw user input.
- **FR-009**: Cancelling the database chooser or the search at any point MUST NOT create files, buffers, or other state changes (non-destructive).
- **FR-010**: All other existing behaviors of the object picker (listing, opening source, the save dialog, executing from the buffer) MUST remain available and unchanged except for the added database-scope control.
- **FR-011**: A cross-database search over all databases (`%`) and the optional team stored procedure are OUT of scope for this feature and remain owned by the predecessor multi-DB spec.
- **FR-012**: Non-Sybase schemes MUST keep their current fallback behavior; the database-scope control is a Sybase-only flow.
- **FR-013**: The change MUST pass headless startup, lint/format checks, and the existing database smoke tests; new smoke coverage MUST be added for database-scope selection and owning-database binding.
- **FR-014**: The Neovim module README MUST document the database-scope control, its default, owning-database binding, the out-of-scope cross-database search, and rollback (git revert of the module changes).
- **FR-015**: The change MUST be scoped to the Neovim module; no other tool module may be required to install, update, or remove it.
- **FR-016**: Implementation MUST be developed on a feature branch with conventional commits and submitted through a pull request; the PR MUST verify whether the active specification (this one or the predecessor multi-DB spec) is related and should be closed.

### Key Entities *(include if feature involves data)*

- **Database Scope Selection**: the target database of a search run; defaulted to the connection's current database and chosen from the databases the login can read; cancelling leaves the flow unchanged.
- **Object Search Result**: one picker row — owning database, object name, and object kind; the owning database labels the row and drives source loading and buffer binding.
- **Owning Database**: the database that holds a matched object; directs which database the source is read from, which database the opened buffer executes in, and the database-qualified name of the buffer and saved file.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The developer can set the target database in one action and the picker shows only that database's objects in 100% of tests.
- **SC-002**: 100% of search result rows display their owning database.
- **SC-003**: Opening and executing an object found outside the connected database runs against the owning database in 100% of acceptance tests; zero out-of-database executions.
- **SC-004**: An unknown or inaccessible database choice produces exactly one actionable error and never an empty picker or buffer.
- **SC-005**: Default behavior (no database chosen) is unchanged in 100% of regression tests.
- **SC-006**: Headless startup, lint/format checks, and existing database smoke tests pass, plus the new smoke coverage; the module README documents the control, default, binding, out-of-scope search, and rollback.

## Assumptions

- The list of selectable databases is derived from the databases the login can read at search time; the current connection database is always the default.
- "Setting a database" means picking one specific target database for the search in v1; the server-wide search across all databases (`%`) and the optional team procedure remain owned by the predecessor multi-DB spec.
- Database selection reuses the portable in-batch selection already proven to work on macOS (sqsh) and Windows (isql), so no client-specific flags are needed.
- The connected database and its connection stay untouched: scoping changes only which database the next search runs in, not the connection registry.
- The predecessor multi-DB object-search spec (closed, `specs/archive/2026-09-25-001-multidb-object-search`) owns the cross-database scan and the catalog-based source extraction; this feature owns the database-scope control. If both proceed, the relationship is confirmed at planning time.