# Verify Report: Database Scope for Object Search

## Verification Report

**Change**: 005-database-scope
**Version**: N/A
**Mode**: Standard

### Completeness

| Metric | Value |
|--------|-------|
| Tasks total | 22 |
| Tasks complete | 22 (all `[X]` in `tasks.md`) |
| Intentionally pending | None — live-server acceptance (choosing a real database from a real ASE) is manual-only (no database servers in validation); every code path is covered by the offline smoke test |
| Live-server acceptance | Manual-only: type a real database name, confirm the header changes and the listing comes from that database, then open a procedure and check the buffer + `<leader>qo` save name are database-qualified |

### Archive Closure

- User approval: the user answered `ciérralas todas` on 2026-09-25 to closing/archiving
  `001`, `003`, `004` and `005` together in one change (PR for issue #88).
- Archived path: `specs/archive/2026-09-25-005-database-scope/`.
- Active path status: `specs/005-database-scope/` no longer exists on the branch after archive.
- Task closure: T001…T022 all `[X]` (22/22) in the archived `tasks.md`.
- Spec status: `Closed (archived 2026-09-25; see verify-report.md)` — the status was still `Draft`
  even though the work had landed and been reviewed in the `005-database-scope` PR; this change
  corrects that and records the evidence below.
- Feature pointer: `.specify/feature.json` was already `{"feature_directory":""}` (no active feature).
- FR compliance (unchanged by this change, re-verified on the branch):
  - FR-001 — database-scope control: `Database: <db> — change…` row in the picker +
    `choose_database()`; 41 smoke assertions cover the readable header label, the typed-underscore
    scope and the equal-scope no-refresh.
  - FR-002 — the chosen database drives the listing: `apply_database_scope()` →
    `db#adapter#sybase#with_database()` + re-fetch.
  - FR-003 — safe failures: invalid name, empty/inaccessible listing → exactly one notify + picker
    re-opens on the last-good listing; never an empty picker, never a silent scope revert.
  - FR-004…FR-009 — threaded through source loading, `b:db` binding and the save name; the
    `&` (transaction) edge is a known limitation of the `with_database()` charset contract
    (`[A-Za-z0-9_$#]`), documented in `contracts/sybase-db-scope.md`.
- Internal links updated to the archived paths (`plan.md`, `tasks.md`, and the reference to the
  archived `001` spec in `spec.md`).

### Build & Tests Execution

**Formatting**: ✅ Passed

```text
$ stylua --check nvim
(no output; exit 0)
```

**Smoke check**: ✅ Passed

```text
$ nvim --headless -u nvim/init.lua '+quitall'
(no output; exit 0)
$ nvim --headless -u NORC -c 'so nvim/autoload/db/adapter/sybase.vim' -c 'qa!'
(no output; exit 0)
```

**Smoke tests**: ✅ All passed (offline, `-u NORC`)

```text
$ nvim --headless -u NORC -c 'lua require("tests.db_objects_scope_smoke")' -c 'qa!'
All db_objects scope smoke assertions passed
exit 0     # 41/41 assertions
$ nvim --headless -u NORC -c 'lua require("tests.sybase_objects_smoke")' -c 'qa!'
exit 0     # 28/28 assertions (objects listing + source extraction, incl. the scope URL reaching
           # the source query and the database-qualified buffer name)
$ nvim --headless -u NORC -c 'lua require("tests.db_objects_save_smoke")' -c 'qa!'
exit 0     # 26/26 assertions
$ nvim --headless -u NORC -c 'lua require("tests.db_results_smoke")' -c 'qa!'
exit 0     # 18/18 assertions
$ nvim --headless -u NORC -c 'lua require("tests.sybase_adapter_smoke")' -c 'qa!'
exit 0     # 11/11 assertions
$ nvim --headless -u NORC -c 'lua require("tests.db_jump_smoke")' -c 'qa!'
exit 0     # 7/7 assertions
$ nvim --headless -u NORC -c 'lua require("tests.keymap_groups_smoke")' -c 'qa!'
exit 0     # 6/6 assertions
$ nvim --headless -u NORC -c 'lua require("tests.db_connections_smoke")' -c 'qa!'
exit 0     # 4/4 assertions
$ nvim --headless -u nvim/init.lua -c 'lua assert(vim.g.db_ui_use_nvim_notify, "db_ui_use_nvim_notify not set"); vim.print("PASS notify-routing")' -c 'qa!'
PASS notify-routing
exit 0
```

**Dependency check**: ✅ 0 required missing (`setup/validate-nvim-deps.sh`; 26 checked, 5 optional missing).

**Branch/status check**: ✅ Branch `fix/nvim-db-source-and-docs` (from `main`); issue #88.

### Noteworthy Findings & Limitations

- The spec was still marked `Draft` when archived even though its 22 tasks were complete and the
  behavior was in the shipped config: closing it is a bookkeeping fix, not a behavior change. The
  `005-database-scope` branch and PR are gone; this archived copy plus the source of truth
  (`db#adapter#sybase#with_database()`, `choose_database()`, `apply_database_scope()`) is the record.
- `choose_database()` lists databases with `select name from sysdatabases order by name` on the
  login's default database, so a login without access to `master..sysdatabases` sees only the typed
  path — that is why the typed-name branch exists and is tested.
- The database name contract is `[A-Za-z0-9_$#]`, which excludes the `&` multi-segment ASE names and
  therefore the `%` cross-database scan; this is a deliberate boundary from
  `specs/archive/2026-09-25-001-multidb-object-search/`.
