# Quickstart: Database Scope for Object Search

Validation guide for `005-database-scope`. Two layers: **automated checks** (no live server, no
picker interaction) and **manual acceptance** (interactive). Contract:
[contracts/sybase-db-scope.md](./contracts/sybase-db-scope.md). Data model:
[data-model.md](./data-model.md). Research: [research.md](./research.md).

## Prerequisites

- Neovim 0.11+ with this repo's config (see `nvim/README.md`).
- The `:DBObjects` flow working (a registered `sybase://` connection and readable object source).
- Optional for the cross-database cases: a second readable database on the same server.

## Automated validation (no server required)

Run from the repo root:

```sh
# 1. Headless startup of the whole config
nvim --headless -u nvim/init.lua '+quitall'

# 2. Lua formatting check
stylua --check nvim

# 3. Scope smoke test (pure/headless, canned output):
#    - with_database() swaps the path, preserves auth/host/port/params, rejects invalid names (+ %)
#    - objects() rows carry the `database` field
#    - scope flow: pick a database -> scoped URL -> re-fetch -> rows labelled with owning db
#    - opening a result binds the buffer to the scoped URL and save names are db-qualified
nvim --headless -u NORC -c 'lua require("tests.db_objects_scope_smoke")' -c 'qa!'

# 4. Existing suite still green (predecessor + sibling features)
nvim --headless -u NORC -c 'lua require("tests.sybase_adapter_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.sybase_objects_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.db_objects_save_smoke")' -c 'qa!'
```

Expected: all commands exit 0 (`:cquit` path unused); the scope test prints all `PASS` lines; test 1
starts the config cleanly.

## Manual acceptance (interactive)

### US1 — Choose the database the object search runs in (P1)

1. **Given** a connection whose database is A and a readable database B, **When** `:DBObjects` is run,
   **Then** the picker's first row reads `Database: A — change…` and the listing shows A's objects.
   → FR-001/FR-006, SC-005.
2. **Given** the picker at (1), **When** the scope entry is selected and B is confirmed, **Then** the
   listing shows objects from B only. → FR-002, SC-001.
3. **Given** the chooser open, **When** ESC is pressed, **Then** nothing runs, nothing changes, and
   the previous picker is still there. → FR-009.

### US2 — Open and execute results in their owning database (P1)

1. **Given** the search scoped to B from a connection to A, **When** a procedure of B is opened,
   **Then** the source shown is B's copy, the buffer is named `<B>.<proc>.sql`, and running it
   executes in B. → FR-004/FR-005, SC-003.
2. **Given** two same-named procedures in A and B, **When** both are opened, **Then** their buffers
   are distinctly database-qualified and each keeps its binding. → FR-005, SC-003.
3. **Given** a scoped search in B, **When** a procedure is saved through the dialog, **Then** the file
   is `<B>.<proc>.sql` (database-qualified). → FR-005, SC-003.

### US3 — Clear labels and safe failures (P2)

1. **Given** a scoped search with matches, **When** the picker opens, **Then** every row displays its
   owning database. → FR-003, SC-002.
2. **Given** a chosen database that does not exist or is not accessible, **When** the search is
   attempted, **Then** exactly one actionable error names the database and no picker/buffer opens.
   → FR-007, SC-004.
3. **Given** a scoped search with zero matches, **When** it completes, **Then** a clear no-match
   message appears and no buffer opens. → FR-007.

## Known limitations (accepted)

- The scope control applies to Sybase connections only; SQL Server and MongoDB keep the current
  fallback listing.
- Cross-database search over all databases (`%`) and the team procedure are not part of this feature
  (owned by `001-multidb-object-search`); database names are restricted to
  `[A-Za-z0-9_$#]` so `%` is rejected by construction.
- Scope is per-invocation: each fresh `:DBObjects` starts from the connection's database again.
- Rollback: `git revert` of the Neovim-module changes restores the previous single-database behavior
  with no data loss.