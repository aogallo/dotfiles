# Research: DBUI Query Result Reopen and Notification Routing

Phase 0 consolidation for `006-dbui-query-results`. All technical unknowns were resolved from the installed
plugins (vim-dadbod, vim-dadbod-ui under `~/.local/share/nvim/site/pack/core/opt/`), the existing Neovim
config, and the spec (no `[NEEDS CLARIFICATION]` markers remained). Format: Decision / Rationale /
Alternatives considered.

## R-1 How the module learns a query finished and which file holds its result

- **Decision**: React to dadbod's own `User */DBExecutePre|Post` autocmds (fired at `db.vim:307` and
  `db.vim:329`); the callback derives the output file from the event's matched name via
  `opts.match:gsub('/DBExecute...$', '')` — equivalently `fnamemodify(match, ':h')` in Lua — and records
  `bufnr(outfile)` plus a `running` flag. On `DBExecutePost` the record is committed (latest wins).
- **Rationale**: These are dadbod's public, versioned extension points; `<amatch>`/`match` is the exact
  output file the query wrote, so record and summond operate on the same identity with no globbing or
  guesswork. Firing happens on every query (bang or not), matching "latest finished query wins" (FR-001,
  FR-007). The `:h` trick is already how the config can get the outfile reliably (matches the parent
  directory, which is the `.dbout` path).
- **Alternatives considered**:
  - *Poll `t:db_last_preview_buffer` on summon*: rejected — it is per-tab, holds a buffer number that
    becomes invalid after the preview window closes (`bufhidden=delete`), and cannot distinguish a running
    query (no `DBExecutePost` yet).
  - *Hook `BufRead,BufNewFile *.dbout`*: rejected — fires for parenthetical opens (reopening from the
    drawer, `:vsp` of any `.dbout`) that are not "a query finished"; would record stale/partial content and
    adds a father-state shadow of dadbod's own per-file autocmd.
  - *Wrap `:DB` via a wrapper command*: rejected — must re-implement dadbod's range/`=`/firstName parsing and
    misses queries executed through dadbod-ui's drawer/save-queries paths; the autocmd covers every path.

## R-2 The identity the summon action targets (window vs file)

- **Decision**: Keep a **per-session, single-slot record** (spec Key Entity "Last Query Result Record"):
  `{ outfile: string, bufnr: integer, running: boolean }`. Summon prefers the **window** currently hosting
  the recorded buffer (`win_findbuf`, across tabs; current tab wins) and falls back to **reopening the
  recorded `.dbout` file** with `:pedit` when the buffer is gone. Focus via `nvim_set_current_win` (which
  switches tab if needed) or `:pedit` (which enters the preview window).
- **Rationale**: Neovim buffers are global; the same result may be visible in any tab. `win_findbuf` gives
  a window without guessing; if the window is gone, the file still exists (`s:init()` sets
  `nobuflisted bufhidden=delete`, and dadbod never deletes the output file on completion), so `:pedit`
  reopens the exact buffer identity and dadbod's own per-file `BufReadPost` autocmd (registered at
  `db.vim:540-542`) re-runs `s:init()`/`b:db_input`, restoring `dbout` filetype and buffer mappings for
  free — dadbod-ui's `BufReadPost *.dbout nested save_dbout` (`plugin/db_ui.vim:126`) also re-registers it
  in the drawer "Query results" list, kept unchanged (FR-007). A single global slot honors FR-001
  "single per-session slot" and the spec's own entity definition.
- **Alternatives considered**:
  - *Per-tab record mirroring `t:db_last_preview_buffer`*: rejected — the spec explicitly wants "from any
    tab" (FR-002/FR-003, AS-3); per-tab would not know the latest result of another tab.
  - *Write a file/journal in `stdpath('data')`*: rejected — adds persistence we do not need; the temp
    outfile already covers the closed-window case within a session.

## R-3 How a running query is detected so summon stays safe

- **Decision**: Flip a `running` flag in the module: set `true` on `DBExecutePre`, `false` on
  `DBExecutePost`. Summon checks the flag first and, while running (or when nothing was ever recorded),
  returns a single informational notice and creates nothing (spec edge "Query still running").
- **Rationale**: dadbod sets `t:db_last_preview_buffer` and stream-writes the outfile *before* the job
  actually finishes; only `DBExecutePost` proves completion. Pre/Post framing is precisely the pairing dadbod
  publishes, so the flag requires no polling and no inspecting job internals. It also degrades safely: an
  aborted query still ends in `DBExecutePost` (query_callback always fires; `DB: … aborted`), so the flag is
  reset; an error thrown before `filter_write` never fires Pre, leaving `running=false` (safe default).
- **Alternatives considered**:
  - *Inspect `b:db.job` on the result buffer at summon time*: rejected — the buffer may already be deleted
    (window closed) so `b:db` is gone exactly when we need the answer most.
  - *Timeout/timer sweep*: rejected — non-local state, complexity, and does not match dadbod's event model.

## R-4 Reopen mechanics and the missing-file notice

- **Decision**: When the recorded buffer is invalid but the outfile still exists, `:pedit` the
  `fnameescape`d path (same call dadbod-ui's drawer uses, `drawer.vim:472`). Before opening, check
  `filereadable(outfile)`; if absent, emit exactly one warning notice and open nothing (FR-008).
- **Rationale**: `:pedit` is the native preview-window open dadbod already uses (`db.vim:545`), so the
  reopened result behaves exactly like dadbod's own result window with no new window type. The explicit
  `filereadable` guard turns the (rare) already-cleaned temp file into a single actionable notice instead of
  an empty/error buffer (spec edge, FR-008).
- **Alternatives considered**: `:sbuffer <buf>` on the stale bufnr — rejected (`nobuflisted` buffers can be
  shown but the number is invalid once `bufhidden=delete` wiped it); `:split` — rejected because it would
  create a full split instead of dadbod's preview-window semantics.

## R-5 Routing dadbod-ui notices to native Neovim notifications

- **Decision**: Set `vim.g.db_ui_use_nvim_notify = true` in the existing vim-dadbod-ui `on_setup` block of
  `nvim/plugin/database.lua` (next to `db_ui_use_nerd_fonts`, `db_ui_save_location`, and the sybase table
  helper — the established place for that plugin's globals). dadbod-ui's `notifications.vim` (lines 12, 66,
  97+) then delivers info/warning/error through `vim.notify`, which this config's `install_notify_wrapper`
  (`nvim/plugin/editor.lua`) routes to the Snacks notifier (top-right native area). "Executing query..."
  info notices use `id = 'vim-dadbod-ui-info'` and, when enabled, remain silencable via
  `g:db_ui_disable_info_notifications` (FR-011).
- **Rationale**: Config-only (FR-010), a one-line toggle at the plugin's config point, no source edits, no
  dependency, and it removes exactly the bottom-left floating overlay dadbod-ui paints while keeping the
  drawer's own results list untouched. Reads of `g:db_ui_use_nvim_notify` happen at first autoload use
  (runtime), always after config load, so the value set in `on_setup` is in effect.
- **Alternatives considered**: *Override `db_ui#notifications#*` with our own wrapper* — rejected, requires
  editing repo-owned plugin source or remapping the upstream namespace; the official option exists for this
  exact purpose. *Keep dadbod-ui floats and only re-theme them* — rejected, fails FR-009 (overlay must be
  gone).

## R-6 Testing strategy

- **Decision**: New `nvim/lua/tests/db_results_smoke.lua` following the module's harness
  (`cquit` on failure, `PASS/FAIL` prints, `db_jump_smoke.lua` style). It drives the autocallbacks directly
  with `vim.api.nvim_exec_autocmds('User', { pattern = '<tmp>/results.dbout/DBExecutePre|Post' })` — no live
  database, no plugin dependency — then asserts: (a) record is empty and summon notifies once before any
  event; (b) Post records `outfile` + buffer and summon focuses the open window; (c) closing the window (the
  mocked preview buffer via `bufhidden=delete` deletion) makes summon reissue `:pedit` on the existing temp
  file and lands on the result buffer; (d) a deleted/missing outfile produces exactly one notice; (e)
  summon while `running=true` (Pre fired, Post not yet) is a no-op notice. US2 is validated by the
  full-config headless check: `nvim --headless -u nvim/init.lua -c 'lua assert(vim.g.db_ui_use_nvim_notify); vim.print("PASS notify-routing")' -c 'qa!'`.
- **Rationale**: Matches the module's established headless smoke convention (FR-014) and validates every
  summon scenario plus the record lifecycle without a server; interactive confidence goes to `quickstart.md`.
- **Alternatives considered**: only live/`-u nvim/init.lua` validation — rejected, the NORC smoke is the
  precedent and keeps CI fast and hermetic.