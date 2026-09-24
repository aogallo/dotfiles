# Quickstart: DBUI Query Result Reopen and Notification Routing

Validation guide for `006-dbui-query-results`. Two layers: **automated checks** (no live server) and
**manual acceptance** (interactive). Contract: [contracts/db-results.md](./contracts/db-results.md). Data
model: [data-model.md](./data-model.md). Research: [research.md](./research.md).

## Prerequisites

- Neovim 0.11+ with this repo's config (see `nvim/README.md`).
- A registered connection and the query flow working (`:DB` in a SQL buffer or a query from the DBUI drawer).

## Automated validation (no server required)

Run from the repo root:

```sh
# 1. Headless startup of the whole config (loads dadbod-ui on_setup incl. the notify option)
nvim --headless -u nvim/init.lua '+quitall'

# 2. US2 config assert: the notify option is active after full config load
nvim --headless -u nvim/init.lua \
  -c 'lua assert(vim.g.db_ui_use_nvim_notify, "db_ui_use_nvim_notify not set"); vim.print("PASS notify-routing")' \
  -c 'qa!'

# 3. New smoke test — record + summon with a temporary `.dbout`, no live DB:
#    . no record → one notice, nothing created
#    . Post records outfile+bufnr; summon focuses the open window
#    . window closed (buffer wiped) → summon reopens the temp file via pedit
#    . missing outfile → one notice, no buffer
#    . Pre-without-Post (running) → summon is a no-op notice
nvim --headless -u NORC -c 'lua require("tests.db_results_smoke")' -c 'qa!'

# 4. Lua formatting
stylua --check nvim

# 5. Existing suite still green (predecessor + sibling features)
nvim --headless -u NORC -c 'lua require("tests.sybase_adapter_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.sybase_objects_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.db_objects_save_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.db_jump_smoke")' -c 'qa!'
```

Expected: all commands exit 0 (`:cquit` path unused); the smoke test prints all `PASS` lines plus a final
`All db_results smoke assertions passed`.

## Manual acceptance (interactive)

### US1 — Summon the last query result (P1)

1. **Given** a query whose result window is open but not focused, **When** `<leader>qr` is pressed,
   **Then** the result window is focused. → FR-003.
2. **Given** a query whose result window was closed (e.g. `q`/`<C-w>q` on the preview), **When** `<leader>qr`
   is pressed, **Then** the stored result file is reopened in an output window and shown. → FR-004.
3. **Given** a query that ran in a different tab, **When** `<leader>qr` is pressed, **Then** the result
   window is focused regardless of tab (current tab preferred for ties). → FR-003, AS-3.
4. **Given** no query has finished, **When** `<leader>qr` is pressed, **Then** exactly one INFO notice
   `db_results: no query result recorded yet` appears and nothing else changes. → FR-005.
5. **Given** a query still running, **When** `<leader>qr` is pressed, **Then** one INFO notice appears and no
   stale/empty result opens; the key never blocks. → FR-006.
6. **Given** two queries run in sequence, **When** `<leader>qr` is pressed, **Then** the latest finished
   result is brought back (older ones stay in the drawer "Query results" list). → FR-007.
7. **Given** the previously-closed result's temp file has been cleaned (rare), **When** `<leader>qr` is
   pressed, **Then** one WARN notice names the missing file and nothing opens. → FR-008.
8. **Idempotency:** pressing `<leader>qr` repeatedly focuses/reopens the same result; no duplicate buffers
   or windows accumulate.

### US2 — dadbod-ui notifications through native Neovim notifications (P2)

1. **Given** a query starts, **When** the "Executing query..." notice fires, **Then** it appears as a native
   Neovim notification (top-right, Snacks) and the query/code area is not overlaid. → FR-009.
2. **Given** a query completes or fails, **When** dadbod-ui emits its notice, **Then** it appears as a native
   notification with the correct severity (info/error). → FR-009.
3. **Given** `g:db_ui_disable_info_notifications` enabled, **When** a routine info fires, **Then** it stays
   silenced (existing behavior preserved). → FR-011.
4. **Known limitation:** dadbod's own `DB: Query finished in …` echo on the native command line and the query
   progress float are upstream behavior not configurable from this feature; the dadbod-ui floating overlay
   is what goes away.

## Known limitations (accepted)

- The summon path covers the latest finished query only; historical results remain in the DBUI drawer
  "Query results" list.
- Result buffers keep dadbod's preview lifecycle (`nobuflisted`, `bufhidden=delete`); the "persistent
  results" option was explicitly not chosen per spec.
- `g:db_ui_use_nvim_notify` is Neovim-only; the shared config targets Neovim.
- Rollback: `git revert` of the Neovim-module changes restores the previous overlay behavior; no buffers,
  files, or saved state are left behind (the in-memory slot disappears with the Neovim process).