# Implementation Plan: DBUI Query Result Reopen and Notification Routing

**Branch**: `006-dbui-query-results` | **Date**: 2026-09-23 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/006-dbui-query-results/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command; its definition describes the execution workflow.

## Summary

After executing a query the developer loses the dadbod output window (preview `:pedit`) once they navigate
away or close it, and there is no one-key way to bring the last result back. This feature adds
`<leader>qr` (under the existing `database` keymap group) to **summon the last finished query result** from
any tab and window: the module records the output file and its window on dadbod's `User */DBExecutePost`
autocmd into a single in-memory per-session slot; summoning focuses the recorded buffer if it still has a
window (across tabs, preferring the current tab), reopens the recorded `.dbout` file in a preview window if
the buffer was wiped (`bufhidden=delete` leaves the temp file on disk), and otherwise shows exactly one
clear notice. Query execution and the popup-on-close lifecycle stay untouched (the "persistent results"
option was explicitly not chosen). As a second, smaller user story, dadbod-ui's execution notices
("Executing query...", info/warning/error floats) are routed through the native Neovim `vim.notify` system
(already displayed by Snacks in this configuration) by enabling the upstream `g:db_ui_use_nvim_notify`
option — config-only, no source edits, no new dependency.

## Technical Context

**Language/Version**: Lua (Neovim 0.11+, new `nvim/lua/config/db_results.lua`) with the keymap in
`nvim/lua/config/keymaps.lua` and the dadbod-ui option in `nvim/plugin/database.lua` (existing `on_setup`).

**Primary Dependencies**: vim-dadbod (pack/core/opt — provides the `User */DBExecutePre|Post` autocmds, the
preview-window result lifecycle, and the per-file `BufReadPost` autocmd that re-binds a reopened `.dbout`
buffer via `s:init()`/`b:db_input`), vim-dadbod-ui (drawer "Query results (N)" list + `g:db_ui_use_nvim_notify`
routing), Snacks notifier as the active `vim.notify` handler (`nvim/plugin/editor.lua`,
`install_notify_wrapper`). No new dependencies (FR-010).

**Storage**: none — one in-memory per-session slot (`outfile`, `bufnr`, `running` flag). No files created,
no persisted state; the `.dbout` temp file the summon path reopens is dadbod's own (it is never deleted on
completion, only when the preview buffer is wiped).

**Testing**: headless smoke (`nvim --headless -u NORC -c 'lua require("tests.db_results_smoke")' -c 'qa!'`)
exercising record + summon with a temporary output file and no live database; full-config headless startup
(`nvim --headless -u nvim/init.lua '+quitall'`) plus a one-liner asserting the notify option is active;
`stylua --check nvim`; existing database smoke suite. New `nvim/lua/tests/db_results_smoke.lua`.

**Target Platform**: Neovim on macOS. The config is Neovim-only; `g:db_ui_use_nvim_notify` is supported
only on Neovim upstream, matching the spec assumption. No Apple Silicon/Intel divergence.

**Project Type**: Neovim configuration module inside the macOS dotfiles repository (`nvim/`).

**Performance Goals**: summon is O(1) (one window lookup, optional one `:pedit`); autocallbacks are
constant-time and non-blocking; no polling, timers, or busy loops.

**Constraints**: zero source edits to dadbod/dadbod-ui; query execution and the popup-on-close behavior
must not change; at most one clear notice per summon; keymap lowercase-only after `<leader>` (`<leader>d`
reserved) in the existing `database` (`<leader>q`) group; 60%-keyboard-safe; only the latest finished query
result is summonable (older results stay in the drawer list unchanged).

**Scale/Scope**: single-user Neovim config; a handful of query results per session — far below any limit.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

How this plan satisfies each applicable dotfiles constitution gate:

- **Portability**: pure portable Neovim Lua using public dadbod autocmds and APIs; no user-specific absolute
  paths (the `.dbout` path comes from `expand('<amatch>')` at runtime, never hardcoded) and no secrets;
  identical behavior on any Neovim platform.
- **Idempotency**: the in-memory slot is updated on every `DBExecutePost` (latest wins, FR-001/FR-007);
  repeated `<leader>qr` presses only refocus/reopen the same result — no duplicate buffers or windows
  accumulate (spec edge case); no installer behavior change.
- **Non-destructive safety**: summoning with no result, a running query, or a missing file is a pure no-op
  with a single notice (FR-005/FR-006/FR-008); the existing result window and drawer are never modified
  beyond focusing; `:pedit` on reopen uses dadbod's own file and its `nobuflisted bufhidden=delete`
  lifecycle untouched.
- **Modularity**: change is scoped to the Neovim module (`nvim/`); two small edits plus a new module and a
  new smoke test; no other tool module must be installed, updated, or removed (FR-012).
- **Source of truth**: repository-managed Lua and `nvim/README.md` updated in-repo; no generated files,
  secrets, or local overrides introduced.
- **Dependencies**: no new dependencies; vim-dadbod, vim-dadbod-ui, and Snacks are already declared in the
  module's manifest/README (FR-010).
- **Security**: no credentials involved; the recorded path is a temp file path used only to reopen the
  result — never logged or stored beyond the in-memory slot.
- **Verification**: headless whole-config startup, a one-line notify-option assert, `stylua --check nvim`,
  the new `db_results` smoke test, and the existing database smoke suite all gate completion (FR-014).
- **Installer UX**: not applicable — no installer surface is changed.
- **Recovery**: documented rollback = `git revert` of the Neovim-module changes, restoring the previous
  overlay behavior with no buffers, files, or saved state left behind (spec edge case / FR-015).
- **Maintainability**: small additions to two existing files plus one new module and one new smoke test; no
  new abstractions or frameworks beyond dadbod's own autocmds.
- **Documentation**: `nvim/README.md` updated for the `<leader>qr` behavior, the notification routing, the
  native dadbod echo limitation, and rollback (FR-015).
- **Module README**: `nvim/README.md` is the module README and covers purpose, source-of-truth files,
  prerequisites, validation, customization boundaries, and rollback; it will be updated in this change.
- **Spec navigation**: `tasks.md` will include a marker legend and link each user-story phase to its
  matching `spec.md` heading; non-story phases stay unlinked.
- **Branch/PR discipline**: implementation lands on feature branch `006-dbui-query-results`, commits use
  conventional messages targeting the branch, and the PR links the approved issue and verifies whether this
  active specification should be closed on merge.

No violations require justification; the Complexity Tracking table is left empty.

## Project Structure

### Documentation (this feature)

```text
specs/006-dbui-query-results/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
│   └── db-results.md
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
nvim/
├── README.md                    # module README — document <leader>qr + notification routing + rollback (FR-015)
├── lua/config/db_results.lua    # NEW module: DBExecutePre/Post autocallbacks, per-session slot, summon()
│   └── (setup() wires autocmds; show() is the <leader>qr action)
├── lua/config/keymaps.lua       # + <leader>qr in the --database group (FR-002)
├── lua/tests/db_results_smoke.lua  # NEW smoke suite (record + summon with temp outfile) (FR-014)
└── plugin/database.lua          # + vim.g.db_ui_use_nvim_notify = true in the dadbod-ui on_setup (FR-009),
                                 #   ~ db_results.setup() call
```

**Structure Decision**: the feature is one new single-file module (`db_results.lua`, following the same
style as `db_jump.lua`/`db_objects.lua`) plus two one-line wiring edits and one new smoke test. No new
directories, entry points, or plugins are introduced; this matches the modular-tool-boundary and simplicity
principles. The dadbod-ui notify option lives next to the other dadbod-ui globals already set in its
`on_setup` block (`plugin/database.lua`), the established convention for that plugin's config.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

None. The plan introduces no constitutional exceptions.