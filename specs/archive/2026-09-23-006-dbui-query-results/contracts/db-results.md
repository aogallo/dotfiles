# Contract: DBUI Query Result Reopen and Notification Routing (006-dbui-query-results)

Defines the event contract, the module surface, the keymap, and the notification-routing config for the
Neovim module (`nvim/`). No vim-dadbod / vim-dadbod-ui source is modified; all integration is through
public autocmds and options.

## 1. Events — vim-dadbod extension points (consumed)

dadbod already fires these; the module only reacts:

- `User */DBExecutePre` — pattern `<outfile>/DBExecutePre`. Callback sets `running = true`.
- `User */DBExecutePost` — pattern `<outfile>/DBExecutePost`. Callback:
  1. `outfile = fnamemodify(match, ':h')` (the `.dbout` path, per [research.md R-1](./research.md));
  2. `slot = { outfile = outfile, bufnr = bufnr(outfile), running = false }` (record, latest wins).
- `bufnr(outfile)` is the result buffer dadbod just opened (`:pedit`, `db.vim:545`); its number is recorded
  at Post time and treated as possibly-stale afterwards.

Non-goal: the module never emits, alters, or re-fires these events, and never touches dadbod's own
per-file `BufReadPost` autocmds (`db.vim:540-545`) or dadbod-ui's `BufReadPost *.dbout` (`db_ui.vim:126`).

## 2. Module surface — `nvim/lua/config/db_results.lua` (NEW)

### 2.1 `db_results.setup()` — called from `nvim/plugin/database.lua` at config load

Registers the two `User` autocallbacks (§1). Idempotent; safe when dadbod is absent (callbacks simply never
fire). Does NOT set `g:db_ui_use_nvim_notify` (that lives with the other dadbod-ui globals, §4).

### 2.2 `db_results.show()` — the summon action (<leader>qr)

Order of checks (exact behavior per spec FR-005/FR-006/FR-003/FR-004/FR-008):

1. **No record**: `slot.running == false and slot.outfile == nil`
   → one INFO notice `db_results: no query result recorded yet`; return `nil`.
2. **Running**: `slot.running == true` (Pre fired, Post not yet)
   → one INFO notice `db_results: query still running`; return `nil` (no stale/empty buffer, no blocking).
3. **Buffer valid with window**: `nvim_buf_is_valid(slot.bufnr)` and
   `wins = vim.fn.win_findbuf(slot.bufnr)` non-empty
   → focus `wins[1]` when it is in the current tab; otherwise focus the current-`wins` one (any tab; the
     focus implicitly switches tab). Return the focused window.
4. **Buffer wiped, file present**: `win_findbuf` empty **and** `vim.fn.filereadable(slot.outfile) == 1`
   → `:pedit fnameescape(outfile)` (dadbod-ui drawer parity); dadbod's `BufReadPost` re-binds the buffer
     (`b:db_input`, `dbout` filetype, mappings) and dadbod-ui re-registers it in the drawer list (FR-007).
     Return the new preview window.
5. **File gone**: anything else with a recorded `outfile`
   → one WARN notice `db_results: output file no longer exists (<outfile>)`; return `nil` (no buffer
     created).

Guarantees: never creates files, never mutates query state, never touches the drawer, at most one notice,
idempotent across repeated calls.

## 3. Keymap — `nvim/lua/config/keymaps.lua`

- `nmap <leader>qr` → `require('config.db_results').show`, `{ desc = 'Database results', silent = true }`,
  placed in the existing `--database` block (next to `<leader>qj/q u/q o`), lowercase-only per keybinding
  conventions. The which-key `database` group registration is the pre-existing pending `editor.lua` change;
  this map does not add or move groups.

## 4. Notification routing — `nvim/plugin/database.lua` (US2)

- In the vim-dadbod-ui `on_setup` block add: `vim.g.db_ui_use_nvim_notify = true`.
- Effect (upstream, config-only): `db_ui#notifications#info/#warning/#error` (including "Executing query...")
  call `vim.notify` (notifications.vim:66-67, 97-110). This config's `install_notify_wrapper`
  (`nvim/plugin/editor.lua`) hands them to the Snacks notifier → native top-right area, no bottom-left
  overlay (FR-009/FR-010).
- Severity mapping stays dadbod-ui's: `info` → INFO (`opts.id = 'vim-dadbod-ui-info'`), `warning` → WARN,
  `error` → ERROR. `g:db_ui_disable_info_notifications` continues to silence the routine info (FR-011).
- Known limitation (spec AS-red, FR per spec Assumptions): dadbod's own native `DB: Query finished in …`
  command-line echo is not configurable upstream and remains; the change removes dadbod-ui's floating
  overlay only. The query progress float also stays (out of scope by assumption).

## 5. Out of contract (explicit non-goals)

- "Persistent result buffers" (the non-chosen option): dadbod's `nobuflisted`/`bufhidden=delete` preview
  lifecycle is preserved; this feature only summons/reopens.
- Historical results: the drawer "Query results (N)" list and its opening behavior are untouched.
- dadbod source, dadbod-ui source, and the `:DB`/`:DBUIToggle` command grammars are never modified.
- The database keymap group itself (`<leader>q` which-key registration) is the pending `editor.lua` change,
  owned separately.