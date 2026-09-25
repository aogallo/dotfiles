# Verify Report: Fix Object Save

## Verification Report

**Change**: 004-fix-object-save
**Version**: N/A
**Mode**: Standard

### Completeness

| Metric | Value |
|--------|-------|
| Tasks total | 0 (no `tasks.md` was ever written for this spec) |
| Tasks complete | 0 |
| Intentionally pending | The reopen-with-same-name edge case, which stays tracked as a bug if it re-appears (see below) |
| Delivered by issue #88 | US4 / FR-007 / FR-008 — the opened buffer carries only the object's definition text, and the saved file is byte-identical to it |

### Archive Closure

- User approval: the user answered `ciérralas todas` on 2026-09-25 to closing/archiving
  `001`, `003`, `004` and `005` together in one change (PR for issue #88).
- Archived path: `specs/archive/2026-09-25-004-fix-object-save/`.
- Active path status: `specs/004-fix-object-save/` no longer exists on the branch after archive.
- Spec status: `Closed (archived 2026-09-25; see verify-report.md)` with the closure note recorded in
  `spec.md` (superseding the 2026-09-23 note).
- FR compliance:
  - FR-001…FR-006 (the save dialog contract: always asks, startup-root default, database-qualified
    names, no silent overwrite, cancel is a no-op) — **met**, delivered by
    `specs/archive/2026-09-23-002-procedure-save-dialog/` and reinforced by
    `specs/archive/2026-09-24-007-fix-dbobjects-scope-save-dir/`; still green in
    `db_objects_save_smoke` (26 assertions).
  - FR-007 (buffer content is only the object's definition text — no client banners, column
    headings, row counts, prompts, or blank framing lines) — **met** by issue #88. The previous
    `sp_helptext` path put `# Lines of Text`, the row count, the `text` heading and a dashed
    separator at the top of every opened object; the source now comes from `syscomments` and the
    client framing is stripped by `s:clean_result()`.
  - FR-008 (buffer ↔ file byte equality) — **met**: `M.write_source()` writes exactly the lines the
    buffer shows, and with the 255-byte rows reassembled the two no longer diverge from the
    catalog's stored text.
  - FR-009…FR-012 — **met** by the two specs above (actionable single messages, no crashes, no
    unrelated module touched).
  - FR-013/FR-014 — **met**: `nvim/README.md` documents the save behavior, buffer naming, artifact
    cleaning, `g:db_sybase_source_mode` and rollback; the change is scoped to `nvim/` (plus README
    link updates in `zsh/README.md` for a pre-existing broken path).
- Feature pointer: `.specify/feature.json` was already `{"feature_directory":""}` (no active feature).
- Internal link updated to the archived predecessor path
  (`specs/archive/2026-09-23-002-procedure-save-dialog`).

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
```

**Smoke tests**: ✅ All passed (offline, `-u NORC`)

```text
$ nvim --headless -u NORC -c 'lua require("tests.db_objects_save_smoke")' -c 'qa!'
exit 0     # 26 assertions (fresh + overwrite save -> exactly one notify with the full path,
           # keep-existing -> zero write + zero notify, single write, startup-root default)
$ nvim --headless -u NORC -c 'lua require("tests.sybase_objects_smoke")' -c 'qa!'
exit 0     # 28 assertions, incl. framing stripping and byte-exact chunk reassembly (FR-007/FR-008)
$ nvim --headless -u NORC -c 'lua require("tests.db_objects_scope_smoke")' -c 'qa!'
exit 0     # 41 assertions
$ nvim --headless -u NORC -c 'lua require("tests.db_results_smoke")' -c 'qa!'
exit 0     # 18 assertions
$ nvim --headless -u NORC -c 'lua require("tests.sybase_adapter_smoke")' -c 'qa!'
exit 0     # 11 assertions
$ nvim --headless -u NORC -c 'lua require("tests.db_jump_smoke")' -c 'qa!'
exit 0     # 7 assertions
$ nvim --headless -u NORC -c 'lua require("tests.keymap_groups_smoke")' -c 'qa!'
exit 0     # 6 assertions
$ nvim --headless -u NORC -c 'lua require("tests.db_connections_smoke")' -c 'qa!'
exit 0     # 4 assertions
```

**Dependency check**: ✅ 0 required missing (`setup/validate-nvim-deps.sh`; 26 checked, 5 optional missing).

**Branch/status check**: ✅ Branch `fix/nvim-db-source-and-docs` (from `main`); issue #88.

### Noteworthy Findings & Limitations

- The spec's own note (line 145 before archiving) said the 255-byte wrapping limitation "remains
  documented and is owned by the upstream catalog-based extraction feature (001, FR-013)". That is
  now false in the other direction: the catalog extraction landed in this same change, so FR-007 is
  satisfied by construction instead of by artifact stripping on top of `sp_helptext`.
- The reopen-with-same-name defect is **not** fixed here; per the spec it should be tracked as a new
  bug if it re-appears, which is why it is recorded as intentionally pending rather than delivered.
- Live-server acceptance (opening, saving and re-running a real procedure) is manual-only: no
  database server in validation.
