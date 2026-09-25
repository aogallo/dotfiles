# Verify Report: Multi-Database Object Search

## Verification Report

**Change**: 001-multidb-object-search
**Version**: N/A
**Mode**: Standard

### Completeness

| Metric | Value |
|--------|-------|
| Tasks total | 0 (no `tasks.md` was ever written for this spec) |
| Tasks complete | 0 |
| Intentionally pending | The cross-database `%` scan (FR-001/002/004/005/006) and the team stored-procedure integration — both explicitly out of scope by decision, see below |
| Delivered by issue #88 | FR-013 (catalog-based source extraction, no mid-token cuts), FR-014 (actionable notice when the text is unreadable) |

### Archive Closure

- User approval: the user answered `ciérralas todas` on 2026-09-25 to closing/archiving
  `001`, `003`, `004` and `005` together in one change (PR for issue #88).
- Archived path: `specs/archive/2026-09-25-001-multidb-object-search/`.
- Active path status: `specs/001-multidb-object-search/` no longer exists on the branch after archive.
- Spec status: `Closed (archived 2026-09-25; see verify-report.md)` with the closure note recorded in
  `spec.md` (superseding the 2026-09-23 note).
- FR compliance:
  - FR-001…FR-006 (cross-database `%` scan) — **not implemented, out of scope by decision**. The
    per-database scope shipped by `005-database-scope` covers the daily need; a search across every
    accessible database is not planned in this repo. Reopen as a new feature if that requirement
    returns.
  - FR-007 (exact original text in a buffer bound to the owning database) — **met**: buffer content
    comes from the stored catalog text (see issue #88 below).
  - FR-008…FR-012 — superseded in practice by `005-database-scope` (database-scope control) and
    `002-procedure-save-dialog` (save naming/dialog); the cross-database variants never shipped.
  - FR-013 — **met** by issue #88: source is read from `syscomments` ordered by `number, colid2,
    colid` and reassembled, so lines longer than 255 bytes stay intact.
  - FR-014 — **met** by issue #88: hidden/encrypted text is detected before reading
    (`status & 1 = 1 or version is not null`) and yields one actionable notice, never a garbled or
    empty buffer.
- Feature pointer: `.specify/feature.json` was already `{"feature_directory":""}` (no active feature).
- Internal links updated to the archived paths (`plan.md`, and the reference from
  `specs/archive/2026-09-25-005-database-scope/spec.md`).

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
$ nvim --headless -u NORC -c 'lua require("tests.sybase_objects_smoke")' -c 'qa!'
exit 0     # 28 assertions, incl. the FR-013 reassembly cases:
           #   255-byte chunk boundary mid-token, syscomments order-by, hidden-text check query,
           #   column-heading/separator stripping, truncated final row, server error -> no source,
           #   showsql opt-in mode (framing stripped + sp_helptext 'showsql,noparams')
$ nvim --headless -u NORC -c 'lua require("tests.sybase_adapter_smoke")' -c 'qa!'
exit 0     # 11 assertions (argv/batch invariants unchanged)
$ nvim --headless -u NORC -c 'lua require("tests.db_objects_scope_smoke")' -c 'qa!'
exit 0     # 41 assertions
$ nvim --headless -u NORC -c 'lua require("tests.db_objects_save_smoke")' -c 'qa!'
exit 0     # 26 assertions
$ nvim --headless -u NORC -c 'lua require("tests.db_connections_smoke")' -c 'qa!'
exit 0     # 4 assertions
$ nvim --headless -u NORC -c 'lua require("tests.db_jump_smoke")' -c 'qa!'
exit 0     # 7 assertions
$ nvim --headless -u NORC -c 'lua require("tests.db_results_smoke")' -c 'qa!'
exit 0     # 18 assertions
$ nvim --headless -u NORC -c 'lua require("tests.keymap_groups_smoke")' -c 'qa!'
exit 0     # 6 assertions
```

**Dependency check**: ✅ 0 required missing (`setup/validate-nvim-deps.sh`; 26 checked, 5 optional missing).

**Branch/status check**: ✅ Branch `fix/nvim-db-source-and-docs` (from `main`); issue #88; the fix
lands in the same PR (`fix(nvim): read object source from syscomments with opt-in showsql fallback`).

### Noteworthy Findings & Limitations

- The reassembly cannot be done with a plain row marker: `syscomments` rows already contain the
  object's real newlines, and one row is a 255-char slice that may end mid-line. A single sentinel
  cannot tell "row ended on a newline" from "row was cut mid-line", so the query appends
  `'~' + case when text like '%' + char(10) then ' ' else '+' end`: a row that ended on a real
  newline renders `~ ` alone on its last output line, a mid-line row renders `~+` glued to the
  partial line. `s:join_chunks()` then rebuilds the text stream and splits it once.
- In Vim regex a **bare `~` never matches a literal tilde** (only `\~` or `[~]` do). This silently
  broke the first implementation; it is now noted in the `s:join_chunks()` header.
- The hidden/encrypted probe returns the label `'HIDDEN'`/`'OK'` instead of a count: with a bare
  count, a stray numeric client line (a row count when `set nocount on` did not apply) would be read
  as "hidden" and silently produce an empty buffer.
- Live-server acceptance (opening a real procedure from a real ASE) is manual-only: no database
  server in validation. The offline smokes cover the SQL text, the framing stripping, the chunk
  reassembly and every empty-result branch.
- Known limit carried in code and README: a source line whose last characters are exactly `~` at a
  row boundary is mistaken for the marker, and a lone `CR` line ending is not treated as a break.
