# Quickstart: Multi-Database Sybase Object Search

Validation guide for the `001-multidb-object-search` feature. Two layers: **automated checks**
(no live server needed) and **manual acceptance** (requires a reachable Sybase ASE).
Contract: [contracts/sybase-search.md](./contracts/sybase-search.md).
Data model: [data-model.md](./data-model.md). Research: [research.md](./research.md).

## Prerequisites

- Neovim 0.11+ with this repo's config (see `nvim/README.md`).
- The existing Sybase adapter prerequisites: `sqsh` on macOS (SAP ASE `isql` on Windows) for any
  `sybase://` connection.
- No new dependencies, no procedure installation required: the native scan works with nothing
  configured. The team procedure (optional) needs to exist on the server with the 6 output columns
  documented in the spec.

## Setup for local use

1. (Optional) In your Neovim globals, set the procedure override:

   ```lua
   g.db_sybase_search_proc = "master..mi_procedimiento"  -- two-part, default owner in <db>
   ```

   Leave it unset to use the native non-blocking scan.

2. Start Neovim, run `:DBObjects <name-fragment>` on a `sybase://` connection.

## Automated validation (no server required)

Run from the repo root:

```sh
# 1. Headless startup of the whole config
nvim --headless -u nvim/init.lua '+quitall'

# 2. Lua formatting check
stylua --check nvim

# 3. Adapter syntax/source check
nvim --headless -u NORC -c 'so nvim/autoload/db/adapter/sybase.vim' -c 'qa!'

# 4. Search argv smoke (stubbed db#url#parse): asserts object_search() builds the
#    expected native multi-database batch (isolation 0 + use sections + go→\go) and,
#    when g:db_sybase_search_proc is set, the expected exec batch
nvim --headless -u NORC -c 'lua require("tests.sybase_search_smoke")' -c 'qa!'

# 5. Source argv smoke (stubbed db#url#parse): asserts source() now queries syscomments
#    (ordered by number, colid2, colid) and concatenates chunks — NO sp_helptext
nvim --headless -u NORC -c 'lua require("tests.sybase_objects_smoke")' -c 'qa!'

# 6. Registry/picker smoke: with NVIM_DB_CONNECTIONS pointing at a throwaway registry,
#    assert g:dbs is populated and db_objects.lua completes over it
NVIM_DB_CONNECTIONS=/tmp/fake-db-connections.lua \
  nvim --headless -u nvim/init.lua '+lua assert(vim.g.dbs and next(vim.g.dbs))' '+qa!'

# 7. Missing-client behavior: uninstall/rename sqsh, then
nvim --headless -u NORC -c 'call db#adapter#sybase#object_search("sybase://u@h/db", "%foo%", "P", "%")' -c 'qa!'
#    must yield a single actionable "executable not found" style error naming sqsh/isql — no crash
```

Expected: all commands exit 0; tests 4–5 print argv assertions with all passes (search smoke
covers both engine paths, objects smoke asserts the `syscomments` query shape and the 255-byte
chunk reassembly, including a line >255 bytes with no mid-token cut).

## Manual acceptance (live ASE server)

### US1 — Schema object search across all databases (P0)

1. **Given** a `sybase://` connection, **When** `:DBObjects foo` runs, **Then** the picker lists
   matches from every accessible user database (system databases excluded), each row showing
   `database  kind  name  (owner)`. → FR-001/004, SC-001.
2. **Given** the procedure override **not** configured, **When** the search runs, **Then** no error
   and results come from the native scan; verify on the server during the search that no row locks
   are taken on a database the search is scanning (e.g. `sp_lock` shows no table/page locks from
   `sqsh`'s SPID). → FR-005, SC-009.
3. **Given** `g:db_sybase_search_proc = "master..mi_procedimiento"` (real proc), **When** the
   search runs, **Then** the same row shape renders, with owner/date/time from the procedure.
   → FR-002.
4. **Given** the override set to a misspelled name, **When** the search runs, **Then** exactly one
   actionable error names the configured procedure; follow-up runs with the unset override work.
   → FR-010.
5. **Given** a target database with restricted access, **When** the search runs with `%`, **Then**
   that database surfaces as a diagnostic while other databases still return rows. → FR-006.

### US2 — Open exact procedure text (P0)

1. **Given** a procedure with lines longer than 255 bytes (the reported cut) or wrapped
   variables/conditions, **When** it is picked, **Then** a buffer opens containing the byte-exact
   source: no mid-token line breaks, no chunk artifacts. → FR-013, SC-005; research.md documents
   the reassembly.
2. **Given** an encrypted/hidden-text object (`sp_helptext` would refuse it), **When** it is
   picked, **Then** an actionable notice explains the text cannot be read — never a garbled or
   empty-looking buffer. → FR-014.
3. **Given** the same object name in two databases, **When** both are opened, **Then** buffers are
   named `<db>.<name>.sql`, each `b:db` points at its owning database, and running the buffer
   (`:DB` / dadbod execute) targets that database. → FR-008, FR-011.

### US3 — Existing single-database behavior unchanged (P0)

1. **Given** an active connection, **When** `:DBObjects` runs with no name, **Then** the listing of
   the connected database behaves exactly as before. → FR-011, SC-010.

## Known limitations (accepted)

- The optional procedure must emit the six documented columns in order from every database it
  reports; the adapter normalizes, it does not re-order.
- The native scan reads the catalog at isolation level 0: catalog rows for an object being
  created/dropped concurrently may be missed or duplicated in the picker; the open step
  re-verifies the object's existence.
- Source extraction is Sybase-only (`syscomments`); SQL Server/MongoDB schemes keep their native
  `tables()` behavior with no procedure-source action.