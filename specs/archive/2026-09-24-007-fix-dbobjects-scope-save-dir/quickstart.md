# Quickstart: Fix DBObjects Scope Feedback and Save Confirmation

**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Contract**: [contracts/dbobjects-scope-save-feedback.md](./contracts/dbobjects-scope-save-feedback.md)
**Date**: 2026-09-24

Prereqs for the live scenarios: Neovim with the `nvim/` module and a reachable Sybase server registered in
`nvim/db-connections.lua` (or `NVIM_DB_CONNECTIONS`).

## Automated checks

```sh
stylua --check nvim
nvim --headless -u nvim/init.lua '+quitall'
nvim --headless -u NORC -c 'lua require("tests.sybase_adapter_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.sybase_objects_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.db_connections_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.db_jump_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.db_objects_save_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.db_objects_scope_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.db_results_smoke")' -c 'qa!'
nvim --headless -u NORC -c 'lua require("tests.keymap_groups_smoke")' -c 'qa!'
```

Each smoke test exits nonzero (`:cquit`) on assertion failure and prints `PASS <name>` per assertion.

## US1 — Scope stays visible and stable

**Automated** (`db_objects_scope_smoke.lua`): with `db#url#parse`, `with_database`, `objects`, and
`complete_database` stubbed:

1. Scope to a database whose name contains `_` (e.g. `my_schema_db`) via the typed-name path → header shows
   `my_schema_db`, listing re-fetched in it, searching finds a procedure that exists there (FR-002/FR-004).
2. Scope fails (named DB unreadable / returns no objects) → exactly one error notification and the picker
   re-opens on the last-good listing with the previous scope (FR-003).
3. Typing a name equal to the current scope → one message, picker stays, listing unchanged (FR-003).
4. Cancelling the chooser → picker returns to the last-good list, zero side effects (FR-005).

**Manual** (live server):

1. Run `<leader>qo` with a connection whose URL has no database → header must read `login default`.
2. Pick `Database: login default — change…`, choose a database from the list → header + listing switch to it.
3. Reopen, pick `[type a database name…]`, type e.g. `my_schema_db`, Enter → header shows `my_schema_db`;
   search for a stored procedure that exists there and confirm it appears.
4. Type a clearly invalid name (e.g. `db name`, `a/b`) → one clear error, picker stays on the previous list.
5. Type the exact name of the current scope → one clear message, no refresh, picker stays.

Expected: never a silent fallback to `login default`, never a vanished picker after a scope attempt.

## US2 — Save confirmation with path

**Automated** (`db_objects_save_smoke.lua`): stub `vim.ui.select`/`vim.ui.input` + `writefile`

1. Choose a destination via `[type a path…]` → on success, exactly one `vim.notify` fired containing the full
   path + filename, and the file was written once to that directory and nowhere else (FR-006/FR-007).
2. Fresh save and overwrite-confirmed save each notify exactly once.
3. Existing file + `Keep existing (cancel)` → no write, no notification, zero side effects.

**Manual** (live):

1. Open any procedure/function source from `<leader>qo` → the save dialog appears **starting at the directory
   where Neovim was opened** (general overview).
2. Navigate into a subfolder (or pick `[type a path…]` and type one), confirm → a notification shows the full
   `<dir>/<database>.<object>.sql` path; the file exists there and only there (nothing in the startup root).
3. Reopen another source in the same session → the dialog still starts at the startup root (no memory).

Expected: one notification per save, one file in the confirmed destination, default stays at the startup root.

## US3 — `<leader>q` database keymap group

**Automated** (`keymap_groups_smoke.lua`): load the which-key registry from `nvim/plugin/editor.lua` and assert a
`<leader>q` → `database` group entry exists alongside the four action maps (FR-010).

**Manual**: on a full config (`nvim --headless -u nvim/init.lua`), press `<leader>q` without a trailing key —
the which-key popup must show a `database` group containing `qj`, `qu`, `qo`, `qr`; each action behaves
unchanged.

## Rollback

Revert the `nvim/` changes from this feature (Config files and README) via a normal `git revert` of the merge;
no saved files, buffers, or state are created or altered by the feature itself beyond user-confirmed saves.