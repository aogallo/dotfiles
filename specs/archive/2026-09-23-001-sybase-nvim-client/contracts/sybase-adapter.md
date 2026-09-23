# Contract: Sybase dadbod Adapter (`sybase://`)

**Owner**: Neovim module (`nvim/autoload/db/adapter/sybase.vim`)
**Consumers**: vim-dadbod (`db#adapter#dispatch`/`db#adapter#supports`), vim-dadbod-ui (browser),
vim-dadbod-completion (table completion)
**Related spec**: FR-001/002/003/008/010/019, US1/US3/US4

## URL Grammar

```
sybase://[user[:password]@]host[:port]/[database][?params]
```

- Scheme: `sybase`. Credentials and path follow dadbod URL rules (`db#url#parse`).
- `password` may be a `$ENV_VAR` placeholder (resolved by dadbod at connect time).
- Supported query params: `charset` (client charset, e.g. `iso_1`) — optional.
- `host` is the **registered server name** (as configured in `sql.ini`/interfaces on Windows or
  `interfaces` on macOS); the adapter passes it verbatim to `-S <host>` and resolves the port from
  the client configuration. A `:port` must NOT be appended: adding one breaks clients such as the
  portable MS `isql` (DB-Library error 53 `specified sql server not found`).
- Missing host errors from dadbod's URL resolution.

## Adapter Functions (dadbod dispatch interface)

The file defines `db#adapter#sybase#*` functions; dadbod auto-discovers the scheme from the
runtimepath (`autoload/db/adapter/sybase.vim`).

| Function | Signature | Contract |
|----------|-----------|----------|
| `interactive` | `(url) → argv[]` | argv to open an interactive console with the selected client |
| `input` | `(url, infile) → argv[]` | argv to execute the SQL file `infile` against the server; MUST return a command that runs the file non-interactively and streams stdout+stderr |
| `tables` | `(url) → string[]` | Table/view names for the connected database (from `sysobjects` type `U`/`V`) |
| `objects` | `(url) → {name, kind, owner?}[]` | Schema objects for the search filter: tables (`U`), views (`V`), procedures (`P`), functions (`F`/`X`) |
| `source` | `(url, name) → string[]` | Full stored-procedure definition lines (`sp_helptext <name>`); empty array if absent or missing client |
| `complete_database` | `(url) → string[]` | Database names available on the server |
| `canonicalize` | `(url) → string` | Normalize/validate the URL (may be omitted; dadbod falls back to identity) |
| `input_extension` | `(...) → 'sql'` | Query temp-file extension |
| `output_extension` | `(...) → 'dbout'` | Result temp-file extension |

Functions marked optional may be omitted; dadbod only calls those it can dispatch.

## Client Selection

- macOS (default): `sqsh`, with override variable `g:db_sybase_client` (string or list argv).
- Windows (`has('win32')`): SAP ASE `isql`, override `g:db_sybase_client` also honored.
- Unsupported platform: `tables()`/`objects()`/`complete_database()` return `[]` and `source()`
  returns `[]`; connect paths surface dadbod's `executable()` "not found" error (FR-010/SC-009).

## Query Execution Semantics (`input`)

1. Read `infile` (a dadbod-provided temp file containing the SQL batch).
2. **macOS/sqsh only**: write a transformed copy to a new OS temp file where each line matching
   `^\s*go\s*$` (case-insensitive) becomes `\go`. Never modify the user's original file.
3. Build argv:
   - sqsh: `sqsh -S <host[:port]> -U <user> [-P <password>] [-L semicolon_hack=false] [-J <charset>] -i <copy>`
   - isql: `isql -S <host> -U <user> [-P <password>] -n -w <width> [-J <charset>] -i <infile>` (no
     transform; isql understands `go` natively). `-n` suppresses the `n>` input prompts that
     would pollute the result buffer; `-w <width>` widens the 80-column default (configurable via
     `g:db_sybase_width`, default `32000`). `-w` applies only to `isql`; it is not passed to
     `sqsh`.
4. Database selection is **portable and does not use a `-D` flag**: SAP ASE's `isql` accepts `-D`,
   but FreeTDS/portable `isql` builds reject it with `unknown option D`. Instead, a `use <db>`
   line is prepended to every batch (in both `input`'s transformed copy and the `run_query` batch
   used by `tables`/`objects`/`source`/`complete_database`) whenever the URL carries a database
   path. A URL without a database route ("`/`" or no path) emits no `use` line.
5. stdout and stderr are merged by dadbod into the result buffer, so `print`/`raiserror`
   messages and ASE diagnostics are visible (FR-002).
6. Exit status: nonzero → dadbod reports "Query aborted" (FR-003 contract).

Interactive console (`interactive`): same client/credentials without the `-i` flag; macOS users
submit batches with `\go` (documented in the module README). Interactive consoles start from the
login default database; session-level `use <db>` remains available for manual selection.

## Output Integrity

- No truncation: dadbod streams all output to the result file/buffer (SC-002).
- `isql` runs with `-n -w` so the `n>` prompts never appear in output and wide rows do not wrap at
  80 columns. The dash separator lines between result sets are preserved: vim-dadbod-ui's
  `foldexpr` uses them to fold per-query blocks. Header suppression on the scripted paths
  (`tables`/`objects`/`complete_database`/`source`) uses `-h` (sqsh) or `-b` (SAP ASE `isql`);
  the portable MS `isql` variant may not implement `-b` and should be verified with `isql -?`
  (documented limitation).

## Completion Semantics (`tables`, `complete_database`)

- `tables(url)`: run `select name from sysobjects where type in ('U','V') order by name` against
  the connected database using the same client path, parse the output, and return object names.
- `complete_database(url)`: `select name from sysdatabases order by name`.
- Missing client → `[]` (browser shows no objects; no crash).
- vim-dadbod-completion provides table completion via `tables()`; column completion for this
  scheme is NOT provided (plugin hardcodes column parsing for other schemes) — documented
  limitation, graceful degradation (FR-008).

## Schema Object Search & Source Loading (FR-019/022)

Consumed by `nvim/lua/config/db_objects.lua` via `:DBObjects` (not by dadbod's dispatch loop):

- `objects(url)`: `select name, type from sysobjects where type in ('U','V','P','F','X') order
  by name`, parsed into `{name, kind}` rows (`kind` derived from the type letter). The picker
  renders rows as `kind  name` so fuzzy filtering by name works like SSMS. For non-`sybase`
  schemes the picker falls back to dadbod's native `tables()` (filter works for SQL Server and
  MongoDB; no procedures).
- `source(url, name)`: `sp_helptext <name>` run through the same client argv path; output lines
  are returned whole (no truncation, per FR-002 semantics). `name` is bracketed/quoted and
  single quotes are escaped before interpolation — never interpolate raw user input into SQL.
- Action mapping: selecting a `table`/`view` opens the default "List" query
  (`select top 200 * from <name>`, ASE-safe — no `LIMIT`); selecting a `procedure`/`function`
  fetches `source(url, name)` and opens a new buffer (`filetype=sql`) containing the full text.
  Missing client → `[]`/empty buffer with the same actionable error as connect paths.

## Security

- Passwords are never logged, committed, or echoed into SQL; they flow only via argv to the
  client. Users should prefer `$ENV_VAR` placeholders.
- Temp transformed files live under the OS temp dir; no credential material is written to them
  (credentials are argv-only).
