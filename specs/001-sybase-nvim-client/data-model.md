# Data Model: Sybase / Neovim Database Client

Derived from the feature spec Key Entities and the dadbod/dadbod-ui integration points.

## Entities

### Database Connection

A named profile describing how to reach one database. Maps to dadbod URLs and dadbod-ui
`g:dbs` entries.

| Field | Type | Description | Constraints |
|-------|------|-------------|-------------|
| `name` | string | Display name shown in the DB browser | Unique per registry; lowercase-friendly |
| `url` | string | dadbod connection URL | Must use a supported scheme: `sybase://`, `sqlserver://`, `mongodb://` (see contract) |
| `scheme` | derived | Database type from URL prefix | One of `sybase`, `sqlserver`, `mongodb` for v1 |
| `host` | derived | Server host from URL | May be a hostname or IP |
| `port` | derived | Server port from URL | Sybase ASE default 5000 |
| `database` | derived | Database name from URL path | Optional; affects `-D`/default database |
| `user` | derived | User from URL userinfo | Optional when using passwordless/trusted flows |
| `password` | derived | Secret from URL userinfo or `$VAR` | NEVER committed; env placeholder supported |

Validation rules:
- URL must parse with dadbod's `db#url#parse` (URL-encoded credentials).
- `sybase://` URLs are routed to the custom adapter; `sqlserver://` and `mongodb://` use
  dadbod's native adapters.
- No real credentials may appear in committed files (FR-007); secrets stay in env or the
  ignored registry file.

### Connection Registry

The single user-owned source of connections (FR-004/005). A Lua file returning a name→URL
table, loaded at startup into `g:dbs`.

| Field | Type | Description |
|-------|------|-------------|
| `path` | string | Registry file location; `NVIM_DB_CONNECTIONS` env var, default `stdpath('config')/db-connections.lua` |
| `entries` | map | `{ name = 'url', ... }` — one Database Connection per key |
| `scope` | enum | `user-local` (gitignored or env-sourced); never `repository` when it carries secrets |

Lifecycle:
- Created by the user (template: `nvim/db-connections.example.lua`).
- Loaded at every Neovim startup by the registry loader into `g:dbs` (FR-006: refresh via
  `:DBUI` `R` picks up edits without restart).
- Missing file → empty registry, clear guidance, no crash (edge case: "No registry file").

### Schema Object

A table, view, procedure, or column exposed by a connected server, surfaced for browsing and
completion (FR-008/019).

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Object name (e.g. from `sysobjects` for ASE) |
| `kind` | enum | `table`, `view`, `procedure`, `function`, `column` |
| `connection` | ref | Owning Database Connection |
| `columns` | list | Column names (available natively for SQL Server; degraded for Sybase via vim-dadbod-completion) |

Availability by database type:
- Sybase ASE: tables/views via adapter `tables()`; procedures/functions via adapter `objects()`
  (search filter); column completion not provided by vim-dadbod-completion for this scheme
  (documented limitation).
- SQL Server: tables, columns, context-aware column completion (native support).
- MongoDB: collections via adapter `tables()`; document-field completion not provided.

### Procedure Source

The full definition text of a stored procedure, retrieved from the server and opened in a Neovim
buffer for editing (FR-022, US4#5).

| Field | Type | Description |
|-------|------|-------------|
| `procedure` | ref | The Schema Object (kind `procedure`) it belongs to |
| `text` | text | Full definition text from `sp_helptext <name>`; never a truncated preview |
| `buffer` | path | New `sql` ft buffer opened for the text; editable and re-runnable via the US1 execute flow |

### Query Result

The output of an executed SQL batch, preserved in full (FR-002/SC-002).

| Field | Type | Description |
|-------|------|-------------|
| `content` | text | Full stdout+stderr of the client run (result sets + `print`/`raiserror` messages) |
| `exit_status` | int | Client process exit code; nonzero reported as "aborted" |
| `runtime` | float | Execution wall time reported by dadbod |
| `cancelable` | bool | Job can be stopped via `<C-c>` in the result buffer (FR-003) |
| `output_file` | path | OS temp file dadbod writes output to (no built-in line limit) |

## Relationships

- A Connection Registry contains 1..N Database Connections.
- A Database Connection exposes 0..N Schema Objects (when the server returns metadata).
- A Schema Object of kind `procedure` has 0..1 Procedure Source.
- A Database Connection produces 0..N Query Results (one per execution).
- The adapter maps one Database Connection → one client process invocation (`sqsh` on macOS,
  SAP `isql` on Windows).

## State Transitions

- Registry: `absent` → `created by user` → `loaded into g:dbs` → `edited/refreshed` (no restart).
- Connection: `defined` → `connected` (on `:DB`/browser action) → `failed` (readable error,
  buffer preserved) → `reconnected`/`switched` (no stale session state).
- Query: `running` (progress shown) → `finished` (results rendered) | `canceled` (via `<C-c>`)
  | `failed` (nonzero exit reported).
