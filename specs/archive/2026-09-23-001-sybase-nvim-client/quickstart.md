# Quickstart: Sybase / Neovim Database Client

Validation guide for the feature. Two layers: **automated checks** (no live server needed, run
on any machine) and **manual acceptance** (requires a reachable Sybase ASE / SQL Server /
MongoDB). Contracts: [sybase-adapter.md](./contracts/sybase-adapter.md),
[connections-registry.md](./contracts/connections-registry.md). Data model:
[data-model.md](./data-model.md).

## Prerequisites

- Neovim 0.11+ with this repo's config (see `nvim/README.md`).
- macOS client: `brew install sqsh` (Sybase). Optional for SQL Server:
  `sqlcmd` (`brew tap microsoft/mssql-release && brew install sqlcmd`) or `go install
  github.com/microsoft/go-sqlcmd@latest`; MongoDB: `brew install mongosh`.
- Windows (documented in `nvim/README.md`, FR-021): SAP ASE client (`isql.exe`), Microsoft
  ODBC + `sqlcmd`, `mongosh`. Neovim-on-Windows per `docs/windows-tooling-audit.md`.

## Setup for local use

1. Copy the template: `cp nvim/db-connections.example.lua nvim/db-connections.lua`
2. Fill real connections (or set `NVIM_DB_CONNECTIONS` to point at a registry anywhere).
3. Start Neovim, run `:DBUI` to see the registry connections.

## Automated validation (no server required)

Run from the repo root:

```sh
# 1. Headless startup of the whole config
nvim --headless -u nvim/init.lua '+quitall'

# 2. Lua formatting check
stylua --check nvim

# 3. Adapter syntax/source check
nvim --headless -u NORC -c 'so nvim/autoload/db/adapter/sybase.vim' -c 'qa!'

# 4. Adapter argv smoke test (stubbed db#url#parse):
#    asserts sybase://u:p@h:5000/db → expected sqsh/isql argv, incl. the go→\go transform
nvim --headless -u NORC -c 'lua require("tests.sybase_adapter_smoke")' -c 'qa!'

# 5. Registry-load test: with NVIM_DB_CONNECTIONS pointing at a throwaway registry,
#    assert g:dbs is populated and matches the file
NVIM_DB_CONNECTIONS=/tmp/fake-db-connections.lua \
  nvim --headless -u nvim/init.lua '+lua assert(vim.g.dbs and next(vim.g.dbs))' '+qa!'

# 6. Missing-client behavior: uninstall/rename sqsh, then
nvim --headless -u NORC -c 'call db#adapter#sybase#interactive("sybase://u@h:5000/db")' -c 'qa!'
#    must yield a single actionable "executable not found" style error naming the client

# 7. Object search / source smoke (stubbed db#url#parse):
#    asserts objects()/source() build the expected sqsh/isql argv
nvim --headless -u NORC -c 'lua require("tests.sybase_objects_smoke")' -c 'qa!'
```

Expected: all commands exit 0; test 4 prints the argv assertions (all pass); test 7 prints the
`objects`/`source` argv assertions (all pass); test 6 shows one clear error, no crash.

## Manual acceptance (live servers)

### US1 — Execute large stored procedures against Sybase ASE (P1)

1. **Given** a Sybase connection in the registry, **When** you open a buffer containing a
   `create procedure` batch (using `go` separators, as the team writes them) and run
   `:%DB sybase://...` or the dadbod-ui execute mapping, **Then** the procedure is created and
   any errors appear with line/message context. → FR-001.
2. **Given** a procedure that returns multiple result sets and `print`/`raiserror`, **When**
   executed, **Then** all result sets and messages are visible; nothing truncated. → FR-002/SC-002.
3. **Given** a long query, **When** run, **Then** status shows "DB: Running query..." and
   `<C-c>` in the result buffer cancels it. → FR-003.
4. Interactive: `:DB <sybase-url>` opens the sqsh console; batches run with `\go`. → US1.

### US2 — Connection registry (P2)

1. Add one Sybase, one SQL Server, one MongoDB entry to the registry file. **Then** all three
   appear in `:DBUI` and connect. → FR-005/006, SC-003.
2. Add a fourth entry, press `R` in `:DBUI`. **Then** it appears without restarting Neovim.
   → FR-006, SC-004.
3. Put a real password in the local registry, then scan the repo: `git status` and
   `git log -p` must show no credential. → FR-007, SC-005.

### US3 — Schema completion (P2)

1. With an active connection, open a `*.sql` buffer and type a prefix matching a table. **Then**
   table suggestions appear via the Dadbod blink provider. → FR-008/009, SC-008.
2. Disconnect: blink still completes from LSP/snippets/buffer; no error. → FR-009.

### US4 — Interactive console and browsing for all databases (P3)

1. Run a query against the SQL Server and MongoDB registry connections; results render like
   Sybase. → FR-020.
2. Open the browser on any connection whose server exposes metadata; tables/views/procedures
   are listed; the Sybase "List" helper runs `select top 200 * from <table>` (no `LIMIT`).
   → FR-019.
3. Run `:DBObjects` on a connection with many objects and type a name fragment; the list
   narrows to matching tables/views/procedures immediately (fuzly filter, SSMS-like). → FR-022,
   SC-011.
4. In `:DBObjects`, pick a stored procedure; its full source opens in a new buffer, ready to
   edit and re-run through the US1 execute flow (`:%DB <url>`). → FR-022, SC-011.

## Windows setup (FR-021 / SC-010)

Follow `nvim/README.md` → "Windows database clients": install SAP ASE client (`isql.exe`),
SQL Server ODBC/`sqlcmd`, and `mongosh`; ensure `isql.exe` is on PATH. Set `NVIM_DB_CONNECTIONS`
to a local registry path (or use the default). Run automated checks 1–3 and one US2 smoke test;
the adapter must pick `isql` automatically on Windows.

## Known limitations (accepted)

- Sybase column completion is not provided by vim-dadbod-completion (tables work; columns
  degrade gracefully). SQL Server column completion works.
- The sqsh transform (`go` → `\go`) applies on macOS only; Windows isql needs no transform.
- `:DBObjects` procedure source-loading is Sybase-only; on SQL Server/MongoDB the filter works
  over the native `tables()` (tables/collections), with no procedure source action.
