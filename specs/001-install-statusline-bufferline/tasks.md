# Tasks: Statusline and Bufferline Upgrade

**Feature**: `001-install-statusline-bufferline`
**Spec**: `specs/001-install-statusline-bufferline/spec.md`
**Plan**: `specs/001-install-statusline-bufferline/plan.md`

## Marker Legend

- `T###` — task identifier (sequential)
- `[X]` / `[ ]` — completed / pending
- `[US#]` — task belongs to user story # in `spec.md`
- `[P]` — parallel-safe task (does not block dependent tasks)

## Overview

Replace the custom Neovim statusline with lualine.nvim and add bufferline.nvim as the primary visible buffer list. Use the existing `vim-pack` plugin pattern, preserve the `<leader>b` buffer domain, and remove redundant status/buffer UI instead of layering plugins over custom code.

## Dependency Graph

```text
T001 (baseline)
  └── T002 (declarations) ──> T003 (install + lockfile)
                              ├──> T004 ─> T005 ─> T006 ─> T007   [US1 statusline]
                              └──> T008 ─> T009                   [US2 bufferline]
                              └──> T010 ─> T011                   [US3 keymaps]
                              └──> T012 ─> T013 ─> T014           [polish]
```

Story completion order: US1 → US2 → US3 → Polish. US2 and US3 do not block each other; they block only on Phase 2.

## Phase 1: Setup

- [X] T001 Verify baseline: run `stylua --check nvim` and `nvim --headless -u nvim/init.lua '+quitall'` from the repo root and confirm both pass before any change

## Phase 2: Foundational

- [X] T002 Add `nvim-lualine/lualine.nvim` and `akinsho/bufferline.nvim` to the eager `add { ... }` list in `nvim/plugin/editor.lua` (mirroring existing plugin specs with `src`; no `opts` needed yet)
- [X] T003 Start Neovim so `vim.pack` installs the new plugins, then run `:packupdate ++lockfile` and confirm `nvim/nvim-pack-lock.json` now includes `lualine.nvim` and `bufferline.nvim` entries with pinned revisions

## Phase 3: User Story 1 - Status area (lualine) [P1]

Goal: One global statusline shows mode, branch, file identity, diagnostics, filetype, encoding, and position.

See [User Story 1 in spec.md](../spec.md#user-story-1---see-editor-status-clearly-priority-p1).

- [X] T004 [US1] Add `opts` to the lualine entry in `nvim/plugin/editor.lua` configuring sections: `mode`, `branch`, `filename` (with `file_status = true`), `diagnostics`, `filetype`, `encoding`, `location`
- [X] T005 [US1] Confirm `globalstatus` matches the existing `laststatus = 3` intent in `nvim/lua/config/options.lua`, setting `globalstatus = true` if lualine defaults need it for a single global statusline
- [X] T006 [US1] Remove `require 'statusline'` from `nvim/init.lua` and delete `nvim/lua/statusline.lua`
- [X] T007 [US1] Grep `nvim/` for `statusline.lua`, `statusline.require`, and `vim.o.statusline` references; confirm no remaining references exist

## Phase 4: User Story 2 - Buffer list (bufferline) [P1]

Goal: A visible buffer list marks the active buffer, updates on open/switch/close, and stays minimal for single-buffer sessions.

See [User Story 2 in spec.md](../spec.md#user-story-2---understand-and-manage-open-buffers-priority-p1).

- [X] T008 [P] [US2] Add `opts` to the bufferline entry in `nvim/plugin/editor.lua`: `mode = 'buffers'`, `diagnostics = 'nvim_lsp'`, `diagnostics_update_on_event = true`, `show_buffer_close_icons = true`, `modified_icon`, `auto_toggle_bufferline = true`
- [X] T009 [P] [US2] Confirm bufferline renders icons correctly through the existing `nvim-tree/nvim-web-devicons` entry in `nvim/plugin/editor.lua` (no duplicate devicons declaration)

## Phase 5: User Story 3 - Keymap consistency [P2]

Goal: Buffer navigation uses `<S-h>`/`<S-l>` (Shift+h/l) only, muted from which-key; redundant leader navigation keymaps are removed.

See [User Story 3 in spec.md](../spec.md#user-story-3---keep-keymaps-consistent-by-workflow-domain-priority-p2).

- [X] T010 [US3] Verify existing buffer keymaps in `nvim/lua/config/keymaps.lua` (`<leader>bn`, `<leader>bp`, `<leader>bx`) and `nvim/plugin/editor.lua` (`<leader>bo`) still work and keep their descriptions
- [X] T011 [US3] Add bufferline-specific mappings only if they improve a concrete workflow (e.g. `:BufferLinePick` under `<leader>bb` already served by `fzf-lua`); otherwise leave the `<leader>b` domain untouched and record the decision in this file
- [X] T015 [US3] Add `<S-h>` (next buffer) and `<S-l>` (previous buffer) mappings in `nvim/lua/config/keymaps.lua`
- [X] T016 [US3] Remove `<leader>bn` and `<leader>bp` from `nvim/lua/config/keymaps.lua`
- [X] T017 [US3] Mute `<S-h>`/`<S-l>` from which-key using `hidden = true` in the which-key spec in `nvim/plugin/editor.lua`

## Phase 6: User Story 4 - Startup dashboard [P2]

Goal: A startup dashboard renders header, recent files, and keymaps sections using Snacks.

See [User Story 4 in spec.md](../spec.md#user-story-4---welcome-screen-dashboard-priority-p2).

- [X] T018 [US4] Add `dashboard = { enabled = true, sections = ... }` to the Snacks `opts` in `nvim/plugin/editor.lua` with sections: `header`, `recent_files`, `keys`
- [X] T019 [US4] Confirm the dashboard only shows when opening Neovim without a file argument (Snacks default)

## Final Phase: Polish & Cross-Cutting

- [X] T012 Update `nvim/README.md` with a short section documenting lualine/bufferline behavior and the validation commands from `specs/001-install-statusline-bufferline/quickstart.md`
- [X] T013 Run `stylua --check nvim` and `nvim --headless -u nvim/init.lua '+quitall'` from the repo root; fix any failures before continuing
- [X] T014 Perform the manual UI validation in `specs/001-install-statusline-bufferline/quickstart.md` (three files, active-buffer identification, close/navigate buffers, no duplicate status/buffer UI). **Evidence**: manually validated and approved by the user on 2026-08-14 (dashboard header renders "neovim", buffer navigation via `<S-h>`/`<S-l>`, no duplicate statusline/buffer UI).

## Parallel Execution

- US1 (T004-T007), US2 (T008-T009), and US3 (T010-T011, T015-T017) can run in parallel once Phase 2 completes, since they touch separate concerns (lualine sections vs bufferline opts vs keymaps). Do not run T006 (file deletion) until T004 is confirmed working in a headless startup.
- T018-T019 (dashboard) depend on Snacks already being configured in `nvim/plugin/editor.lua` (Phase 2) and can run in parallel with US1/US2.
- T012, T013, T014 are sequential polish steps after all user stories.

## Implementation Strategy (MVP first)

1. **MVP = US1**: land lualine with the global statusline and retire the custom statusline (T004-T007). This alone satisfies the primary P1 story and is independently testable via headless startup.
2. **Then US2**: bufferline list (T008-T009), independently testable.
3. **Then US3**: switch buffer navigation to `<S-h>`/`<S-l>` and remove redundant leader keymaps (T015-T017), then verify (T010-T011).
4. **Then US4**: Snacks startup dashboard (T018-T019).
5. **Finally polish**: docs + full validation (T012-T014).

## Test Criteria per Story

- **US1 (independent)**: `nvim --headless -u nvim/init.lua '+quitall'` exits cleanly and the statusline renders mode, filename, diagnostics, and position in a real UI without legacy statusline.
- **US2 (independent)**: Opening three files shows a bufferline marking the active buffer; closing a buffer updates the list and focus moves predictably.
- **US3 (independent)**: A keymap review confirms `<S-h>`/`<S-l>` move between buffers, `<leader>bn`/`<leader>bp` are gone, and the new mappings do not appear in which-key.
- **US4 (independent)**: Opening Neovim without a file shows the dashboard with header, recent files, and keymaps; opening a file does not.
