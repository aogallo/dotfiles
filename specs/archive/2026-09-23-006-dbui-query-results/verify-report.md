# Verify Report: DBUI Query Result Reopen and Notification Routing

## Verification Report

**Change**: 006-dbui-query-results
**Version**: N/A
**Mode**: Standard

### Completeness

| Metric | Value |
|--------|-------|
| Tasks total | 14 |
| Tasks complete | 14 |
| Tasks incomplete | 0 |
| Intentionally pending | None — live-server acceptance (real query via `:DB`, `<leader>qr` across tabs) is documented in `quickstart.md` as manual-only (no database servers in validation); all code paths are covered by offline smoke tests |
| Live-server acceptance | Manual-only, documented in `quickstart.md` (DBUI drawer release, close preview then `<leader>qr`, running-query notice) |

### Archive Closure

- User approval: The user answered `se cierra todo` to closing/archiving `specs/006-dbui-query-results/` on 2026-09-23 (PR #84 open against `main`).
- Archived path: `specs/archive/2026-09-23-006-dbui-query-results/`.
- Active path status: `specs/006-dbui-query-results/` no longer exists on the branch after archive.
- Task closure: T001-T014 all marked `[x]` in archived `tasks.md` (14/14).
- Feature pointer: `.specify/feature.json` cleared to empty (no active feature) in the same closing change.
- FR compliance: FR-001…FR-016 (16/16) implemented; verified by `db_results_smoke.lua` (offline) plus the config assertions below.

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
$ nvim --headless -u NORC -c 'lua require("tests.db_results_smoke")' -c 'qa!'
18/18 PASS: no record -> nil + one info notice + no buffer; running query -> nil + notice; focus existing result window (win_findbuf) leaves result buffer current; repeated summon refocuses same window with no new buffers (idempotency); closed window -> :pedit reopen of the recorded .dbout file, bufname matches, result takes focus; missing output file -> one WARN notice + no buffer.
exit 0
```

**Configuration routing** (US2): ✅ Passed

```text
$ nvim --headless -u nvim/init.lua -c 'lua assert(vim.g.db_ui_use_nvim_notify, "db_ui_use_nvim_notify not set"); vim.print("PASS notify-routing")' -c 'qa!'
PASS notify-routing
exit 0
```

**Regression smokes**: ✅ All passed

```text
$ nvim --headless -u NORC -c 'lua require("tests.sybase_adapter_smoke")' -c 'qa!'
exit 0     # 11/11 assertions
$ nvim --headless -u NORC -c 'lua require("tests.sybase_objects_smoke")' -c 'qa!'
exit 0     # 21/21 assertions
$ nvim --headless -u NORC -c 'lua require("tests.db_connections_smoke")' -c 'qa!'
exit 0
$ nvim --headless -u NORC -c 'lua require("tests.db_jump_smoke")' -c 'qa!'
exit 0
$ nvim --headless -u NORC -c 'lua require("tests.db_objects_save_smoke")' -c 'qa!'
exit 0
```

**Branch/status check**: ✅ Feature branch `006-dbui-query-results` (from `origin/main`); commits `d5534a7` (feat) and `7670556` (docs(tasks-006)); PR #84. `nvim/plugin/editor.lua` carries an uncommitted which-key group label only (pre-existing, intentionally not part of the PR).

### Noteworthy Findings & Limitations

- `:pedit` never moves the cursor into the preview window on its own — the summon reopen path and the smoke test must resolve the window hosting the `.dbout` buffer via `win_findbuf(bufnr(outfile))`, not `nvim_get_current_win()`.
- dadbod's own `DB: Query finished in …` native cmdline echo and the query progress float are upstream vim-dadbod behavior and are not configurable; the feature removes the dadbod-ui bottom-left overlay only (documented in `nvim/README.md`).