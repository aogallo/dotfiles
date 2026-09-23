# Feature Specification: Sybase / Neovim Database Client

**Feature Branch**: `001-sybase-nvim-client`

**Created**: 2026-08-14

**Status**: Closed (archived 2026-09-23; see `verify-report.md`)

**Input**: User description: "necesito conectarme a una base de datos sql llamada SYBASE actualmente el equipo que entre utiliza isqlw y crimson para ejecutar stored procedure muy grandes, pero para mi es muy tedioso utilizar ese tipo de herramientas que ni tiene colores o la experiencia de usuario no es buena. Por lo tanto, quiero utilizar database en neovim te voy a dar un listado de plugins el que mantiene la conexion creo que no puede conectarse a SYBASE por lo que no se si sea lo mejor. adicional me gustaria tener las conexiones en un archivo por ejemplo en la config de neovim o que yo diga de donde puede ir a tomarla porque tambien podria conectarme a una sql server o mongo db. [vim-dadbod, vim-dadbod-completion, vim-dadbod-ui, blink.cmp dadbod provider]"

## Clarifications

### Session 2026-08-14

- Q: Platform scope → A: macOS and Windows; Windows-specific client installs must be documented so a Windows machine can be set up by following the docs.
- Q: Sybase client per platform → A: `sqsh` on macOS, SAP ASE `isql` on Windows, selected automatically by operating system.

### Session 2026-09-21

- Q: Schema browser object search → A: Add SSMS-like name search/filter across all supported databases and an action that loads a stored procedure's source into a Neovim buffer for editing, so locating and modifying an object no longer requires browsing one at a time.

### Session 2026-09-22

- Q: Sybase connection URL host → A: Use the **registered server name** (as configured in `sql.ini`/interfaces) with **no port**. The adapter passes it verbatim to `-S <host>`; the port lives in the client's server definition. Appending `:port` breaks portable MS `isql` (DB-Library error 53 `specified sql server not found`).
- Q: Query result formatting → A: isql runs with `-n -w` so the `n>` input prompts never pollute the result buffer and wide columns stop wrapping at the default 80. `g:db_sybase_width` tunes the width (default `32000`). The dash rows isql emits are what enable vim-dadbod-ui folding.
- Q: Adapter implementation language → A: Keep the adapter in Vimscript (`sybase.vim`). The planned port to Lua is SUSPENDED; no restructuring.

### Session 2026-09-23

- Q: Database window navigation keymaps → A: Group everything under `<leader>q` with a second letter per action so `<leader>q` stays a pure which-key prefix (no action+group collision): `<leader>qj` toggles/jumps to the database window (`lua/config/db_jump.lua`), `<leader>qu` runs `:DBUIToggle`, `<leader>qo` runs `:DBObjects`. Return to code via `<leader>qj`, the `L`/`H` buffer cycle, or `<C-o>`/`<C-6>`. Evaluated and rejected on this date: `<leader>d` prefix (reserved for debug) and `<leader>D` (LazyVim builtin conflict + Shift on the 60% keyboard).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Execute large stored procedures against Sybase ASE from Neovim (Priority: P1)

The developer edits a SQL file containing a stored procedure — potentially hundreds or thousands
of lines — and sends the whole buffer (or a selection) to a Sybase ASE server directly from
Neovim. Output comes back in a separate pane: result sets, `print`/`raiserror` messages, and
diagnostics are all visible, nothing is silently truncated. The developer fixes and re-runs in
place. This replaces the team's Windows GUI tools (isqlw, Crimson) as the primary way to work with
Sybase stored procedures.

**Why this priority**: This is the core pain — huge stored procedures run through tools with poor
UX and no color. Solving this first delivers the main value.

**Independent Test**: Can be fully tested by opening a buffer with a `create procedure` batch,
running it against a reachable Sybase ASE instance, then executing the procedure and confirming
all result sets and messages render. Delivers: edit-run-view loop without leaving Neovim.

**Acceptance Scenarios**:

1. **Given** an active Sybase ASE connection, **When** the developer runs "execute whole buffer" on a file containing a `create procedure` batch, **Then** the procedure is created on the server and any errors are reported with useful context (line, message).
2. **Given** a stored procedure that returns multiple result sets and emits `print`/`raiserror` messages, **When** the developer executes it, **Then** all result sets and messages are shown and none are silently truncated.
3. **Given** a long-running query, **When** the developer executes it, **Then** they receive progress/status feedback and can cancel it without a frozen or unusable UI.
4. **Given** a query whose output exceeds the visible pane, **Then** the full output remains available (scrollable/saved) without loss.

---

### User Story 2 - Single user-controlled connection registry (Priority: P2)

The developer keeps every database connection in ONE place they choose — for example a file
inside their Neovim config directory, or any other path they point Neovim at via a documented
configuration value or environment variable. The registry covers Sybase ASE, SQL Server, and
MongoDB in one consistent format. Adding or editing a connection means touching only that
user-owned file (or using the UI's save flow); no repository files change. Credentials never
reach git. New connections appear in the database browser without restarting Neovim.

**Why this priority**: Enables the multi-database goal and centralizes management, but the
single-Sybase loop in US1 already works without it (a connection can come from the environment
or a direct URL).

**Independent Test**: Can be tested by pointing Neovim at a registry file, adding one connection
per supported type, refreshing the browser, and confirming all three appear — while a repository
credential scan finds nothing. Delivers: one place to manage all connections.

**Acceptance Scenarios**:

1. **Given** a user-owned registry file with one Sybase, one SQL Server, and one MongoDB connection, **When** the developer opens the database browser, **Then** all three connections are listed and usable.
2. **Given** the developer adds a new connection entry to the registry file, **When** they refresh the browser, **Then** the new connection is available without restarting Neovim.
3. **Given** a registry location chosen by the developer (config value or environment), **When** Neovim starts, **Then** connections are loaded from exactly that location.
4. **Given** the registry contains a real password, **When** the repository is scanned (working tree and history), **Then** no real credential is found.

---

### User Story 3 - Schema-aware SQL autocompletion (Priority: P2)

While writing SQL and stored procedures, the developer gets autocompletion of schema objects from
the connected database — tables, columns, views, procedures, functions — through the existing
completion engine in Neovim. The completion source activates when a dadbod connection is present
and degrades gracefully when it is not.

**Why this priority**: Directly improves the stored-procedure writing experience and is cheap to
enable once the connection stack exists, but is not required for executing procedures.

**Independent Test**: Can be tested by opening a SQL buffer against an active connection whose
server exposes metadata and confirming that schema-object suggestions appear in the completion
popup; with no connection, Neovim still completes normally.

**Acceptance Scenarios**:

1. **Given** an active connection and a SQL buffer, **When** the developer types a prefix that matches a table or column, **Then** valid schema-object suggestions appear in the completion popup.
2. **Given** no active dadbod connection, **When** the developer types in a SQL buffer, **Then** other completion sources (LSP, snippets, buffer, path) continue to work and no error is shown.

---

### User Story 4 - Interactive console and schema browsing for all supported databases (Priority: P3)

The developer runs ad-hoc queries interactively and browses schema objects (tables, views,
procedures) for SQL Server and MongoDB the same way as for Sybase, using the database browser
and the connection registry.

**Why this priority**: Broadens coverage to the other databases the developer named, on top of
the Sybase-first workflow.

**Independent Test**: Can be tested by connecting to SQL Server and MongoDB via the registry and
running a query plus a schema listing for each. Delivers: consistent multi-database workflow.

**Acceptance Scenarios**:

1. **Given** a SQL Server connection from the registry, **When** the developer runs a query, **Then** results render in the same way as Sybase results.
2. **Given** a MongoDB connection from the registry, **When** the developer issues a query, **Then** results render without leaving Neovim.
3. **Given** any connected database whose server exposes metadata, **When** the developer opens the schema browser, **Then** tables/views/procedures are listed for navigation.
4. **Given** a connected database with many stored procedures, **When** the developer types a name fragment in the schema browser's object filter, **Then** the object list narrows to matching tables/views/procedures immediately.
5. **Given** the schema browser returns a stored procedure from the filter, **When** the developer triggers the source action, **Then** the procedure's full source opens in a Neovim buffer, ready to edit and re-run through the U1 execute flow.

---

### Edge Cases

- **Missing client binary**: a selected connection type whose required local client is not
  installed produces a single actionable error naming the missing tool and how to install it —
  no crash, no partial state.
- **Schema filter with no matches**: a name filter with no matching objects shows a clear
  no-match state without crashing; loading a procedure's source always opens the full text in a
  buffer, never a truncated preview.
- **No registry file**: the first launch with no registry shows an empty browser and clear
  guidance for where to create the file; Neovim still starts normally.
- **Connection failure**: refused connections, bad credentials, and timeouts produce a readable
  error; the developer's buffer and results are preserved.
- **Repeated runs (idempotency)**: re-running setup/linking does not duplicate entries, recreate
  valid state, or reinstall unchanged dependencies.
- **Existing saved connections (non-destructive)**: any previously saved dadbod-ui connections
  are preserved or migrated with a documented backup; nothing is silently overwritten.
- **Credential leakage**: a connection added with an embedded password must not be stageable
  into git; the registry path is gitignored or env-based, and templates contain no real secrets.
- **Very large inputs**: multi-megabyte result sets and very long procedures do not truncate
  silently and remain cancelable.
- **Apple Silicon vs Intel**: the selected Sybase client must be available or installable on
  both, or the limitation must be documented.
- **Per-OS client selection**: the Sybase client resolves to `sqsh` on macOS and SAP `isql` on
  Windows; an unsupported platform or a missing binary produces one clear, actionable message.
- **Headless/CI safety**: startup and validation never require a live database server.
- **Mid-session switching**: switching connections does not require restarting Neovim and leaves
  no stale session state behind.
- **Windows setup**: the developer can follow only the documented Windows steps to install the
  database clients and run the same workflow; environment and path differences between macOS and
  Windows do not require editing shared configuration.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The developer MUST be able to execute a SQL batch or stored procedure from a Neovim buffer against a Sybase ASE server.
- **FR-002**: Execution output MUST include multiple result sets and server messages (`print`/`raiserror`) with no silent truncation.
- **FR-003**: The developer MUST be able to cancel a running query and MUST receive status feedback during long executions.
- **FR-004**: A single user-selected connection registry MUST feed all database features, with its location configurable via a documented configuration value or environment variable and a default outside the git-tracked tree.
- **FR-005**: The registry MUST support Sybase ASE, SQL Server, and MongoDB connections in one consistent format.
- **FR-006**: Connections from the registry MUST become available in the database browser without restarting Neovim.
- **FR-007**: Credentials MUST NOT be committed to the repository; secret-bearing registry files MUST be gitignored or sourced from the environment, and any example/template artifacts MUST contain no real secrets.
- **FR-008**: SQL buffers MUST offer autocompletion of schema objects (tables, columns, views, procedures, functions) derived from the active connection.
- **FR-009**: The completion source MUST integrate with the existing completion engine as a named provider alongside existing sources, and MUST degrade gracefully with no active connection.
- **FR-010**: Required client binaries MUST be declared in the module dependency inventory with install instructions; startup and connection attempts MUST detect a missing client and report an actionable message.
- **FR-011**: Committed configuration MUST contain no user-specific absolute paths; machine- and work-specific values MUST come from the environment or ignored local overrides, and Apple Silicon and Intel MUST be supported where the chosen client allows it.
- **FR-012**: Setup MUST be idempotent and non-destructive: re-running it MUST NOT duplicate entries or overwrite existing saved connections, and any migration MUST create a recoverable backup first.
- **FR-013**: The change MUST pass headless startup, formatting/static checks, dependency validation, and health checks before completion.
- **FR-014**: All changes MUST be scoped to the Neovim module; no unrelated tool module may be required to install, update, or remove.
- **FR-015**: The Neovim module README MUST document source-of-truth files, connection configuration, prerequisites, validation, customization/local-override boundaries, and rollback.
- **FR-016**: Removing the registry or reverting the configuration MUST restore prior behavior without data loss, and any destructive operation MUST have a documented recovery path.
- **FR-017**: Implementation MUST be developed on a feature branch with conventional commits and submitted through a pull request; the PR MUST verify whether the active specification is related and should be closed.
- **FR-018**: Generated task artifacts MUST link each user-story phase back to the matching heading in this specification and include a marker legend.
- **FR-019**: The database browser MUST list tables, views, and procedures for connected databases whose servers expose that metadata.
- **FR-020**: Interactive query execution MUST support all three database types (Sybase ASE, SQL Server, MongoDB) through the same workflow.
- **FR-021**: Windows-specific installation and validation steps for the required database clients MUST be documented so a Windows machine can be set up following only the documentation; the shared configuration MUST remain portable across macOS and Windows, with machine-specific values sourced from the environment.
- **FR-022**: The database browser MUST let the developer filter listed schema objects by name and load a stored procedure's full source into a Neovim buffer for editing.

### Key Entities

- **Database Connection**: a named profile combining database type, host, port, database, and authentication information; the unit the developer creates, edits, and selects.
- **Connection Registry**: the user-owned source (a file, or environment-provided values) that holds connections; its location is chosen by the user and never contains committed secrets.
- **Schema Object**: tables, views, procedures, functions, and columns exposed by the connected server; surfaced for browsing and completion.
- **Query Result**: the result sets and server messages produced by an executed query; rendered in full without silent truncation.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: From the moment the developer issues an execution command, results for a query that completes in under one second on the server appear in Neovim within five seconds.
- **SC-002**: Stored-procedure output (multiple result sets and server messages) renders in full during acceptance testing with zero silent truncations.
- **SC-003**: 100% of the supported database types (Sybase ASE, SQL Server, MongoDB) connect through the single user-controlled registry.
- **SC-004**: Creating or editing a connection requires changes to exactly one user-owned file, and the connection is usable in the browser without restarting Neovim.
- **SC-005**: A credential scan of the working tree and git history finds zero real credentials.
- **SC-006**: Re-running the Neovim setup produces an identical valid state, and all validation commands (headless start, formatting, dependency check) pass.
- **SC-007**: The developer completes an edit-run-view cycle for a stored procedure without leaving Neovim in 95% of sessions.
- **SC-008**: With an active connection whose server exposes metadata, autocompletion presents at least one valid schema-object suggestion.
- **SC-009**: A missing required client produces one actionable error message naming the missing binary and its install command.
- **SC-010**: Following only the documented Windows steps, the developer can set up a Windows machine to run the same database workflow without editing shared configuration.
- **SC-011**: From the schema browser, the developer can narrow objects to a name fragment and open any stored procedure's full source in a buffer within three actions.

## Assumptions

- **Scope**: Sybase ASE, SQL Server, and MongoDB are in scope (named by the user); other databases (MySQL, PostgreSQL, Oracle) are out of scope for v1.
- **Platform**: macOS (Apple Silicon or Intel) is the primary development platform; the same configuration also runs on Windows, and every Windows-specific client installation is documented so the developer can set up a Windows machine following only the documentation. The team's Windows-only GUI tools (isqlw, Crimson) are replaced by Neovim, not replicated.
- **Tooling**: the dadbod family (vim-dadbod, vim-dadbod-ui, vim-dadbod-completion) with blink.cmp are the chosen stack, managed through this repository's native plugin manager — the blink snippet the user referenced comes from LazyVim documentation and will be adapted to this repository's plugin configuration style.
- **Sybase support gap**: vim-dadbod has no built-in Sybase adapter; SQL Server and MongoDB are natively supported. A Sybase connection therefore uses a small adapter that shells out to a local client: `sqsh` on macOS (installed via Homebrew) and the SAP ASE `isql` client on Windows, with the client selected automatically by operating system. Windows installation steps for `isql` are documented. This adapter path was explicitly chosen over a Crimson-style wrapper script (`isql -S … -U … -P … -i %1`) around the isql binary. jTDS/Aqua connection strings (`jdbc:sybase:Tds:host:port/master`) are not valid dadbod URLs — pasting one verbatim yields an "adapter error" — so the registry uses native `sybase://user@server-name/db` URLs (`server-name` = the registered server name, no port; see clarifications) and the module README documents the mapping.
- **Registry hygiene**: the connection registry defaults to a location outside the git-tracked tree and is gitignored when it carries credentials; example files contain no real secrets.
- **Base configuration**: the existing dadbod and dadbod-ui configuration in the Neovim module is the base; previously saved connections are preserved, not discarded.
- **Scale**: large stored procedures (hundreds to thousands of lines) and multi-result-set output must work; silent truncation is unacceptable, and interactive work must not require leaving Neovim.
- **Completion engine**: the completion engine in use is blink.cmp, configured in the Neovim module; the dadbod provider is registered there.
