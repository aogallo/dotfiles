# Feature Specification: Multi-Database Sybase Object Search

**Feature Branch**: `001-multidb-object-search`

**Created**: 2026-09-23

**Status**: Closed

> **Closed** (2026-09-23): the database-scope control this spec depends on landed in
> `005-database-scope` (`:DBObjects` now searches a chosen database). The remaining cross-database
> `%` scan, the catalog-based source extraction, and the team stored-procedure integration stay
> **out of scope** and are not planned in this repo at this time. Marked for closure by the
> `005-database-scope` PR review.

**Input**: User description: "hasta el momento probe :dbojects en neovim y funciona bien me busca la objeto y lo coloca en un buffer nuevo que para mi eso consdiero que es perfecto. Pero creo que unicamente va a buscar a una base de datos y eso genera probelma porque busque otro objeto y no lo encontro entonces mi propuesta va por ejecutar y tenog un preocedimiento que recibe lo siguiente nombre del objeto tipo de objeto que para procedimientos es P que es el que utilizare seguirdo y el ultio es la base de datos, pero si no se la sabe se puede enviar % como string"

## Clarifications

### Session 2026-09-23

- Q1 (stored-procedure contract): the procedure name is NOT hardcoded — it comes from a configuration
  value the developer fills in using Sybase two-part naming (`database..object`, e.g.
  `master..mi_procedimiento`), since the procedure is specific to the developer's Sybase server. The
  procedure first emits diagnostic messages for databases it could not access, then returns one row per
  match with the following columns, in this order: object name, owner/user, date, time, owning
  database, object type. Because the owning database is part of the result set, the found object can
  always be bound to the correct database for source loading and execution.
- Q2 (object types): v1 defaults the object-type parameter to `P` (procedures) and accepts the other
  ASE type letters (`U`, `V`, `F`, `X`) as pass-through, matching how the developer will use it daily.

### Session 2026-09-23 (clarification round 2)

- Q3 (source extraction method): full procedure text is read directly from `syscomments`
  (`select colid, text from syscomments where id = object_id('<object>') order by number, colid`),
  the chunks are concatenated in order and split on real line breaks. This replaces `sp_helptext`
  everywhere in the adapter, so long lines (>255 bytes) never break mid-variable or mid-condition.
  Encrypted objects (unreadable in `syscomments`) surface an actionable notice instead of garbage.
- Q4 (search source & database safety): the cross-database search MUST work WITHOUT the stored
  procedure — a native read-only catalog scan that iterates the accessible databases and queries each
  one's object catalog (name, owner, type, creation date), reusing the existing client path. The
  team's procedure is OPTIONAL: when configured it may replace the native scan and supply its enriched
  columns. Non-negotiable constraint: the search must never block or be blocked by other database
  work — catalog reads take no shared locks (dirty/isolation-0 reads), no DDL, and no temporary
  objects in the target databases.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Find an object no matter which database holds it (Priority: P1)

The developer runs `:DBObjects <fragment>` to locate an object. Today the search only looks inside the database the connection points to, so an object that lives in another database never shows up. After this feature, the same command finds matches across all databases the login can read — by default using a native, read-only catalog scan that never blocks other database work. If the developer's team procedure is configured, it may power the search instead and add its enriched columns (owner, date, time). Every match appears in the picker together with the name of the database that owns it, so identical object names are never ambiguous.

**Why this priority**: This is the reported defect — the search is single-database and returns nothing for objects living elsewhere — and it must work without a hard dependency on the team procedure or on intrusive server work.

**Independent Test**: Connected to database A, the developer types the name of an object that exists only in database B and confirms it appears in the picker labelled with database B (works with no procedure configured); also confirm an object that exists only in A is still found. A name with no matches anywhere shows a clear no-match state. While the search runs, a concurrent write to the searched database completes unimpeded.

**Acceptance Scenarios**:

1. **Given** a connection to database A, an object that exists only in database B, and no stored procedure configured, **When** the developer runs `:DBObjects <name>` for that object, **Then** the native scan finds it and the picker shows its owning database (B) alongside it.
2. **Given** the team procedure IS configured, **When** the developer runs `:DBObjects <name>`, **Then** the search uses it and each row carries the owner, date, and time columns it returns.
3. **Given** the same object name exists in several databases and the search uses the default scope (`%`, all databases), **When** the developer runs `:DBObjects <name>`, **Then** every database containing a match is listed, each row showing its owning database.
4. **Given** a name fragment that matches multiple objects, **When** the picker opens, **Then** results can still be filtered by name exactly as today.
5. **Given** the developer knows which database holds the object, **When** they restrict the search to that database, **Then** only matches from that database are returned.
6. **Given** the login cannot access one or more databases, **When** the search runs, **Then** the affected databases are skipped or reported, the search still completes, and results from the accessible databases appear.
7. **Given** a concurrent write is in progress on a searched database, **When** the search runs, **Then** the search does not block the writer and is not blocked by it (read-only, lock-free catalog reads).
8. **Given** a name with no matches in any database, **When** the search runs, **Then** a clear no-match message appears and no buffer is opened.

---

### User Story 2 - Open and edit the exact procedure text in its owning database (Priority: P1)

Selecting a procedure result opens its full source in a new buffer — the behavior the developer already likes — while the buffer's connection is bound to the database that owns the procedure. Editing and re-running the buffer therefore executes against the correct database, never the database the search happened to be launched from. Buffer names are database-qualified so two same-named procedures from different databases can be open at once without confusion. The opened text is the byte-exact original definition: lines are never split at 255-byte boundaries, so variables and conditions are never cut mid-token.

**Why this priority**: cross-database discovery is only useful if the opened source and the execute flow target the database that actually holds the object, and the text is faithful enough to edit and re-run. The current `sp_helptext` output wraps long lines (saltos de línea) and can split variables or conditions in half.

**Independent Test**: Connected to database A, the developer selects a procedure found in database B; the buffer shows B's full source, executing it runs in B, and the buffer name differs from a same-named procedure opened from A. Selecting a procedure whose definition contains lines longer than 255 characters shows those lines intact.

**Acceptance Scenarios**:

1. **Given** a search result whose owning database differs from the connected one, **When** the developer selects the procedure, **Then** the full source of that database's copy is shown in a new SQL buffer.
2. **Given** an object whose definition has lines longer than 255 characters, **When** the developer opens it, **Then** every original line is preserved intact — no mid-token wrapping of variables or conditions.
3. **Given** the opened source buffer is edited and re-run, **When** the developer executes it, **Then** the execution runs against the owning database.
4. **Given** two open buffers for same-named procedures from different databases, **When** both are visible, **Then** their buffer names are database-qualified and each retains its own database binding.
5. **Given** the procedure is encrypted (its text unreadable on the server), **When** the developer selects it, **Then** an actionable notice explains the object cannot be shown, and no empty or garbled buffer is created.
6. **Given** the procedure returns no source (object dropped or client unavailable), **When** the developer selects it, **Then** a single actionable error appears and no empty buffer is created.
7. **Given** the developer picks a match in a database other than the connected one, **When** the picker confirms the row, **Then** the owning database shown on the row is the database used for source extraction and for the new buffer's connection.

---

### User Story 3 - Control the search by object type and database (Priority: P2)

The developer can tune the search: the object type defaults to `P` (procedures, the daily use case) but other ASE type letters are passed through where the procedure supports them, and the database defaults to `%` (all) but can be a specific database name when the developer already knows it.

**Why this priority**: a refinement on top of the working cross-database search; type/scope control does not block the core value.

**Independent Test**: run `:DBObjects <name>` (defaults), then with an explicit type letter and with an explicit database, and confirm the result kind and database scope change accordingly.

**Acceptance Scenarios**:

1. **Given** no type is specified, **When** the search runs, **Then** the procedure parameter for object type is `P` (procedures).
2. **Given** a supported ASE type letter is supplied, **When** the search runs, **Then** only objects of that kind are returned.
3. **Given** a specific database is supplied, **When** the search runs, **Then** only that database is searched; with no database, `%` covers all databases accessible to the login.

---

### Edge Cases

- **Missing, renamed, or unconfigured stored procedure**: an unset configuration silently selects the native catalog scan; a configured-but-missing or renamed procedure surfaces one actionable error naming it; the search never silently returns an empty list.
- **Long source lines (>255 bytes)**: chunk boundaries never break a variable or condition; the reassembled text preserves the original lines (unlike `sp_helptext` wrapping).
- **Encrypted objects**: an object whose text cannot be read from the catalog shows an actionable notice instead of garbled or empty content.
- **`%` with no matches in any database**: clear no-match state; no buffer is opened.
- **Same object name in multiple databases**: all matches are listed with their owning database so the developer can pick the right one.
- **Login without permission on some databases**: those databases are skipped or reported without aborting the whole search.
- **Object name with special characters (single quotes)**: values are escaped before interpolation — never raw user input in SQL.
- **Missing client binary**: same actionable error as today; no partial state.
- **Buffer name collisions**: opened procedure buffers are database-qualified so same-named objects from different databases do not collide.
- **Very large cross-database result sets**: the picker stays responsive; results remain filterable by name.
- **Non-Sybase schemes (SQL Server, MongoDB)**: keep the current fallback behavior (`:DBObjects` uses dadbod's native `tables()` listing); the cross-database procedure search is a Sybase-only flow.
- **Repeated runs (idempotency)**: re-running searches and re-opening buffers must not duplicate buffers or accumulate stale state.
- **Rollback**: reverting the adapter or the picker module restores the previous single-database behavior with no data loss.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The Sybase adapter MUST provide a cross-database object search that works WITHOUT any stored procedure, using a native read-only catalog scan: iterate the databases the login can read, skip system databases, and query each database's object catalog filtered by object type and name pattern.
- **FR-002**: The team's stored procedure is OPTIONAL: when a documented configuration value (Sybase two-part name, e.g. `master..mi_procedimiento`) is set, the search MAY invoke it with `(object name, object type, database)`, in that order; when the value is unset, missing, or renamed, the search MUST fall back to the native scan and MUST NOT hard-fail.
- **FR-003**: The object type parameter MUST default to `P` (procedures) and MUST pass through the other ASE type letters (`U`, `V`, `F`, `X`); the database scope MUST accept `%` to mean "all databases accessible to the login" and MUST accept a specific database name.
- **FR-004**: Each search result MUST carry the owning database, the object name, and the object type; owner and creation date/time MUST be included when the procedure is configured (enriched columns) or derivable from the catalog in the native scan.
- **FR-005**: The search MUST cause NO blocking and MUST NOT be blocked: catalog reads MUST take no shared locks (dirty/isolation-level-0 reads), MUST NOT create temporary objects in the target databases, and MUST NOT issue DDL. Concurrent writes to any searched database MUST complete unimpeded.
- **FR-006**: Diagnostics for databases the login cannot access MUST be surfaced (procedure messages in the SP path; per-database skip/report in the native scan) and MUST NOT abort the search; only data rows are parsed as results.
- **FR-007**: Selecting a procedure result MUST load its exact original text and open it in a new SQL buffer whose connection is bound to the owning database.
- **FR-008**: Opened procedure-source buffer names MUST be database-qualified to avoid collisions across databases.
- **FR-009**: Object name, object type, and database values MUST be escaped/sanitized before interpolation into any SQL; never raw user input.
- **FR-010**: A missing client, an empty result, or a source that cannot be read MUST surface one actionable message and MUST NOT silently open an empty buffer. An unset procedure configuration is NOT an error — it selects the native scan.
- **FR-011**: `:DBObjects` without a name MUST keep its current behavior (listing objects of the connected database); providing a name MUST trigger the cross-database search.
- **FR-012**: The opened source buffer MUST support the existing execute-and-re-run flow against the owning database (no out-of-database execution).
- **FR-013**: Procedure source MUST be extracted from the catalog directly (chunks ordered by object number and segment, then concatenated and split on real line breaks); `sp_helptext` MUST NOT be used, and lines longer than 255 bytes MUST be preserved intact with no mid-token wrapping.
- **FR-014**: An object whose stored text is unreadable (e.g., encrypted) MUST produce an actionable notice and MUST NOT open a garbled or empty buffer.
- **FR-015**: The change MUST pass headless startup, lint/format checks, and the existing database smoke tests before completion.
- **FR-016**: The Neovim module README MUST document the native scan, the optional procedure configuration, the catalog-based source extraction, the expected result columns, and recovery/rollback.
- **FR-017**: Combined with a registered connection from the search flow, the picker MUST require no restart of Neovim when a new connection is added to the registry.
- **FR-018**: The change MUST be scoped to the Neovim module; no other tool module may be required to install, update, or remove.
- **FR-019**: Implementation MUST be developed on a feature branch with conventional commits and submitted through a pull request; the PR MUST verify whether the active specification (this one or a predecessor) is related and should be closed.
- **FR-020**: Generated task artifacts MUST link each user-story phase back to the matching heading in this specification and include a marker legend.

### Key Entities *(include if feature involves data)*

- **Object Search Result**: one row returned by the procedure — owning database, object name, owner/user, date, time, and object kind (`P`/`U`/`V`/`F`/`X` mapped to labels); the unit presented in the picker.
- **Owning Database**: the database that holds a matched object, as reported by the procedure; it drives which database `sp_helptext` runs in and which connection the opened buffer is bound to.
- **Configured Procedure Name**: the Sybase two-part name (`database..object`) the developer sets in a documented configuration value — OPTIONAL. When set, the search may invoke it for enriched columns; when unset, the search runs the native catalog scan.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: An object that lives only in a database other than the connected one is found and opened within three actions (type name, select match, confirm).
- **SC-002**: 100% of cross-database search results display their owning database.
- **SC-003**: Opening a procedure found in another database loads its source, and executing the buffer runs against the owning database, in 100% of acceptance tests.
- **SC-004**: Zero spoofed executions: no procedure source is loaded or executed against a database other than the one the procedure reported as the owner.
- **SC-005**: An unset procedure configuration silently selects the native catalog scan; a configured-but-missing or renamed procedure produces exactly one actionable error that names what is missing.
- **SC-006**: Diagnostics for databases the login cannot access are visible to the developer, and the search still completes with results from the accessible databases.
- **SC-007**: 100% of tested procedures with lines longer than 255 bytes open with their original lines intact — zero mid-token breaks of variables or conditions.
- **SC-008**: An encrypted (unreadable) object produces exactly one actionable notice, never a garbled or empty buffer.
- **SC-009**: No searched database is blocked by the search: a concurrent write completes normally while a cross-database search is running (verified in acceptance testing against at least one write-active database).
- **SC-010**: Headless startup, lint/format, and existing database smoke tests pass; the module README documents the native scan, optional procedure configuration, catalog-based extraction, expected result columns, and recovery.

## Assumptions

- **Stored procedure availability**: the team's procedure (if used at all) is deployed on the servers the developer connects to and is configured by name via a documented configuration value using Sybase two-part naming (`database..object`). It is OPTIONAL: with no configuration, the search runs the native catalog scan and works fine.
- **Database safety**: the native search is read-only and non-blocking — catalog reads at isolation level 0 (no shared locks), no DDL, no temporary objects in the target databases. The search must never block or be blocked by other database work, per the user's requirement even in dev environments.
- **Source extraction**: procedure text is read from the catalog (`syscomments`) ordered by object number and segment, joined and split on real line breaks; `sp_helptext` is not used. This preserves long lines exactly and removes the 255-byte wrapping seen today.
- **Procedure output shape**: the procedure first emits diagnostics for databases it cannot access, then returns rows with columns (object name, owner/user, date, time, owning database, object type), in that order. The owning database and object type columns are used for binding and label mapping.
- **Wildcard semantics**: the procedure interprets `%` as "all databases accessible to the login", consistent with the user's description; a specific database name restricts the search to that database.
- **Primary use case**: stored procedures (type `P`, default, as the user stated); the other ASE type letters are pass-through (`U`, `V`, `F`, `X`).
- **Scope boundary**: cross-database procedure search is a Sybase-only flow; SQL Server and MongoDB keep their current fallback behavior unchanged.
- **Interaction model**: `:DBObjects` without a name keeps the connected-database listing; providing a name triggers cross-database search via the procedure.
- **Security posture**: name/type/database values are escaped before interpolation, consistent with the existing adapter contract; no new credentials or stored secrets are introduced.
- **Platform**: macOS and Windows continue to work exactly as in the existing Sybase adapter (sqsh / isql), since the new flow reuses the same client execution path.