# Research: Sybase / Neovim Database Client

## Decision: Custom vim-dadbod adapter for Sybase ASE (sqsh on macOS, isql on Windows)

**Rationale**: vim-dadbod has no built-in Sybase adapter (verified in `plugin/dadbod.vim` and
`autoload/db/adapter.vim`: supported schemes are sqlite, postgres, mysql, mariadb, oracle,
sqlserver, mongodb, redis, etc.). Dadbod explicitly supports "your own easily implemented
adapter": an autoload file `autoload/db/adapter/<scheme>.vim` exposing functions that dadbod
dispatches by name (`db#adapter#call`, `db#adapter#supports`, `db#adapter#dispatch` in
`autoload/db/adapter.vim`). The adapter shells out to a client binary exactly like the native
sqlserver/mongodb adapters do.

**Per-OS client split** (user decision, spec Assumptions): macOS uses `sqsh` (Homebrew, portable,
testable in this repo); Windows uses the SAP ASE `isql` client (corporate tooling, already used
by the team with isqlw). The adapter picks the client at runtime by platform, with an override
variable `g:db_sybase_client` for edge cases.

**Alternatives considered**:
- Official SAP ASE client on both platforms — heavier macOS install, license constraints,
  less testable here.
- dbext.vim (has native Sybase ASE profiles) — old, awkward UI, contradicts the user's chosen
  dadbod stack.
- Keep Crimson for Sybase only — rejected by the user (goal is to replace it).
- A wrapper that shells out to a Python/Node driver — adds a heavyweight runtime dependency,
  violates the Simplicity gate; a thin client wrapper matches dadbod's own adapter pattern.

## Decision: sqsh batch-terminator handling (`go` → `\go`) must live in the adapter

**Rationale**: sqsh is NOT a drop-in for isql: its batch separator is `\go`, and a bare `go`
line is either ignored or sent to the server as SQL, breaking stored-procedure batches
(verified via sqsh docs and community reports; the `\go`/`semicolon_hack` behavior is documented
in the sqsh man page). Team SQL files use the isql convention (`go`). Therefore the adapter's
`input(url, in)` function must produce a transformed copy of the input file (`go`/`GO` lines →
`\go`) and run `sqsh -i <copy>`. The transform cannot rely on dadbod's `massage()` hook because
dadbod only applies it in some execution paths (visual selection and `:DB url <query>`), not for
whole-file or `<file` execution (verified in `autoload/db.vim`). Interactive console users type
`\go` themselves (documented). `semicolon_hack` is explicitly disabled (`-Lsemicolon_hack=false`)
to avoid `;` splitting batches inside stored procedures. The transform is macOS/sqsh-only; the
Windows isql path needs no transform (isql understands `go` natively).

**Alternatives considered**: Rewriting every SQL file to `\go` (breaks team files, unacceptable);
a `filter()` using a shell pipeline (not portable to Neovim's `jobstart` argv); relying on
`massage()` (unreliable, see above).

## Decision: Connections registry as a user-owned Lua file, located via `NVIM_DB_CONNECTIONS`

**Rationale**: The user asked for one file, whose location they choose ("que yo diga de donde
puede ir a tomarla"). A Lua `return { name = 'url' }` file needs zero parsing dependencies
(Simplicity gate), is idiomatic in Neovim config, and maps directly onto dadbod-ui's `g:dbs`
table (documented in vim-dadbod-ui README as a first-class connection source). The loader reads
the path from `NVIM_DB_CONNECTIONS` (works on macOS and Windows), defaulting to
`stdpath('config')/db-connections.lua` (i.e. `~/.config/nvim/db-connections.lua`, which is
repo-linked, so it MUST be gitignored). dadbod expands `$VAR` inside URLs at connection time
(verified in `db#resolve`/`s:expand_all`), so users can keep secrets in environment variables
(e.g. `sybase://user:$DB_PASS@server-name/db`, where `server-name` is the registered server
name — no `:port`, which lives in the client's server definition; see clarifications 2026-09-22).
A committed `db-connections.example.lua` documents
the format with no real secrets.

**Alternatives considered**: TOML registry (needs a parser dependency); dotenv.vim (extra plugin,
macOS-oriented); `:DBUIAddConnection` saved `.tbl` files (scattered per-connection, not one
file); hardcoded `g:dbs` in committed Lua (would commit secrets / violate Portability).

## Decision: Schema browsing and completion via the adapter's `tables()`/`complete_database()`

**Rationale**: dadbod-ui lists connections, tables, and runs per-table helpers by calling the
adapter's `tables(url)`; vim-dadbod-completion's table completion uses the same hook (works for
any scheme). The Sybase adapter must implement `tables(url)` against ASE system tables
(`sysobjects`), with display mode configured so parsing is stable. Column-level completion is
NOT supported by vim-dadbod-completion for the Sybase scheme (its column parsing is hardcoded for
PostgreSQL/MySQL/Oracle/SQLite/SQL Server) — table completion works, column completion degrades
gracefully; SQL Server column completion works natively. This satisfies FR-008 for tables and
documents the column-level limitation explicitly.

**Alternatives considered**: Extending vim-dadbod-completion with a Sybase column provider
(fork/maintenance burden, out of v1 scope); using the sqls LSP for columns (sqls does not support
Sybase ASE natively).

## Decision: dadbod-ui table helper for Sybase must avoid `LIMIT`

**Rationale**: dadbod-ui's default "List" helper is `select * from {table} limit 200`, which is
invalid on ASE (no `LIMIT`). The Sybase scheme gets an explicit table helper
`select top 200 * from {table}` via `g:db_ui_table_helpers`, and no quoted identifiers (ASE
`quoted_identifier` default). Without this, every "List" click in the browser fails.

## Decision: Large-output handling needs no special machinery

**Rationale**: dadbod writes query output to a temp file and renders it in a preview buffer
(`writefile(a:lines, a:query.output)` in `autoload/db.vim`) — there is no built-in line limit, so
multi-result-set and multi-megabyte output is preserved (FR-002, SC-002). Async execution
(`jobstart`), merge of stdout+stderr into the same buffer (on_stderr appends), cancellation
(`db#cancel` via `<C-c>` in the result buffer, `jobstop`) and progress status ("DB: Running
query...") are all built into dadbod — no customization needed for FR-003.

## Decision: Windows installation documentation lives in the Neovim module README

**Rationale**: FR-021 requires documented Windows client installs. `nvim/README.md` is the
module's source-of-truth doc (Module README contract) and already the right place for
prerequisites. It will reference `docs/windows-tooling-audit.md` (existing repo document) for
Neovim-on-Windows install (winget/Scoop) and add the DB-client installs: SAP ASE client for
Windows (provides `isql.exe`, the team's tool), Microsoft ODBC + `sqlcmd` (or `go-sqlcmd`) for
SQL Server, and `mongosh` for MongoDB. The adapter resolves isql via `executable()`/PATH; the
docs explain how to make `isql.exe` discoverable (install dir on PATH) so no committed absolute
path is needed.

**Alternatives considered**: New `docs/db-clients-windows.md` — defensible, but the module README
contract already obliges documenting prerequisites in `nvim/README.md`; keeping it there avoids a
second source of truth.

## Decision: Verification strategy is headless + manual acceptance (no live ASE in CI)

**Rationale**: This repository cannot reach the corporate Sybase ASE from validation. Therefore:
(1) syntax/static checks — headless nvim startup, `stylua --check`, source-check of the adapter;
(2) an argv smoke test — a headless script that stubs `db#url#parse` and asserts the adapter
builds the expected `sqsh`/`isql` argv for a given URL, including the `go`→`\go` transform;
(3) manual acceptance against real servers, documented step-by-step in `quickstart.md`
(SC-001/002/007/008 require a live server). Registry load and completion-provider wiring are
verifiable headlessly (fake registry → `g:dbs` populated; blink provider present).

**Alternatives considered**: Dockerized ASE (heavy, licensing, not representative of the
corporate instance); mocking the client with a fake `sqsh`/`isql` binary for integration tests
(useful later, out of v1 scope — deferred).

## Decision: Object search/filter and procedure source loading via fzf-lua picker + adapter hooks

**Rationale**: The clarified FR-022/US4#4-5 requires SSMS-like name filtering of schema objects
and an action that opens a stored procedure's full source in a buffer for editing. Options for
the filter: vim-dadbod-ui's browser buffer has no built-in name filter (its per-table "List"
helper also cannot apply to procedures), and vendoring/overriding upstream dadbod-ui adds
maintenance coupling. The nvim module already ships fzf-lua (`nvim/plugin/fzf-lua.lua`, wired as
the `vim.ui.select` handler), so fuzzy name filtering is available with **zero new dependencies**
(Simplicity gate). The picker is fed by the Sybase adapter from `sysobjects` (types `U`/`V`/`P`/
`F`/`X`), so the same client path used by `tables()` serves the search; selecting a procedure
runs `sp_helptext <name>` (via a new adapter `source(url, name)` hook) and opens the full text in
a new `sql` buffer — ready to edit and re-run through the US1 execute loop. `tables()` stays
tables/views-only so the dadbod-ui tree and its table helpers are unaffected; procedures are
surfaced through the object-search command, which together satisfies FR-019/FR-022.

**Alternatives considered**: Extending/vendoring the dadbod-ui browser buffer with a filter
(upstream coupling, and the "List" helper doesn't respect object kinds); adding
`telescope.nvim` (not present — would add a dependency); native `/` search inside the DBUI
buffer (does not narrow the list, not SSMS-like); including procedures in `tables()` so they
appear in the tree (breaks the per-table "List" helper on procedure rows and pollutes
completion). For non-Sybase schemes the picker falls back to dadbod's native `tables()` — the
filter works for all supported databases; procedure source-loading is Sybase-specific (only the
`sybase://` adapter implements `source()`).
