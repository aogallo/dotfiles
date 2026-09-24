---
description: "Task list for DBUI Query Result Reopen and Notification Routing"
---

# Tasks: DBUI Query Result Reopen and Notification Routing

**Input**: Design documents from `/specs/006-dbui-query-results/`

**Prerequisites**: plan.md (required), spec.md (required for user stories), data-model.md, contracts/db-results.md, research.md, quickstart.md

**Marker Legend**:
- `T###` — stable task ID, sequential execution order.
- `[P]` — parallelizable: touches different files, no dependency on incomplete tasks.
- `[US#]` — task belongs to a user-story phase; the phase's `Story Link` points to the matching `spec.md` heading. Setup / foundational / polish tasks carry no `[US#]`.

**Constitution obligations applied**: validation tasks are REQUIRED (Verification gate VIII), including headless startup, `stylua --check nvim`, smoke tests relevant to the changed module, module README coverage (XIV), rollback/recovery (X), non-destructive/idempotency checks (II/III), and feature-branch/PR workflow verification with active-spec closure review before PR creation (XIII).

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Feature branch and active-feature tracking before any code changes

- [ ] T001 Create and switch to feature branch `006-dbui-query-results` from `main` (never commit to `main`; see `specs/006-dbui-query-results/plan.md`)
- [x] T002 [P] Verify `.specify/feature.json` still points to `specs/006-dbui-query-results` (Spec Kit active-feature tracking)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The `db_results` module skeleton (state + event wiring) that US1 builds on

**⚠️ CRITICAL**: US1 must not start until this phase is complete. US2 depends only on `nvim/plugin/database.lua` and can proceed in parallel.

- [x] T003 Create `nvim/lua/config/db_results.lua`: per-session slot `{ outfile, bufnr, running }`; `M.setup()` registers `User */DBExecutePre` (sets `running = true`) and `User */DBExecutePost` (records `outfile = vim.fn.fnamemodify(match, ':h')`, `bufnr = vim.api.nvim_get_current_buf()` — equivalently `bufnr(outfile)` — and `running = false`) per `contracts/db-results.md` §1/§2.1. Single-file style mirroring `nvim/lua/config/db_jump.lua`; return `M`. No summon logic yet.

**Checkpoint**: Foundation ready — autocallbacks record the last finished result headlessly testable via `nvim_exec_autocmds`.

---

## Phase 3: User Story 1 - Summon the last query result (Priority: P1) 🎯 MVP

**Story Link**: [US1 in spec.md](./spec.md#user-story-1---summon-the-last-query-result-priority-p1)

**Goal**: `<leader>qr` brings the last finished dadbod query result back from any tab and window — focusing the open result window, reopening the recorded `.dbout` file when the preview window was closed, and otherwise showing exactly one notice.

**Independent Test**: `nvim --headless -u NORC -c 'lua require("tests.db_results_smoke")' -c 'qa!'` covers record + summon with a temp `.dbout` and no live database; manual scenarios in `quickstart.md`.

### Implementation for User Story 1

- [x] T004 [US1] Implement `db_results.show()` in `nvim/lua/config/db_results.lua` (depends on T003): exact order per `contracts/db-results.md` §2.2 — (1) no record → one INFO notice `db_results: no query result recorded yet`, return nil; (2) `running` → one INFO notice `db_results: query still running`, return nil; (3) `nvim_buf_is_valid(bufnr)` and `vim.fn.win_findbuf(bufnr)` non-empty → focus window (current tab preferred, else any tab switches tab), return it (FR-003); (4) else `vim.fn.filereadable(outfile)` → `vim.cmd.pedit(vim.fn.fnameescape(outfile))`, return preview window (FR-004); (5) else one WARN notice `db_results: output file no longer exists (<outfile>)`, return nil (FR-008). Never creates files, never mutates query state, at most one notice, idempotent
- [x] T005 [P] [US1] Register keymap `nmap <leader>qr` → `require('config.db_results').show`, `{ desc = 'Database results', silent = true }`, in the existing `--database` block of `nvim/lua/config/keymaps.lua` (next to `<leader>qj/qu/qo`; lowercase after `<leader>`, FR-002)
- [x] T006 [US1] Wire `db_results.setup()` in `nvim/plugin/database.lua` after the `db_objects.setup(...)` call (idempotent; safe when dadbod absent). NOTE: `nvim/plugin/database.lua` is also edited by US2 (T009) — keep both edits in one commit-safe sequence
- [x] T007 [P] [US1] Create `nvim/lua/tests/db_results_smoke.lua` for the harness pattern of `nvim/lua/tests/db_jump_smoke.lua` (`PASS/FAIL` prints, `:cquit` on failure): drive events with `vim.api.nvim_exec_autocmds('User', { pattern = '<tmp>/out.dbout/DBExecutePre|Post' })` and assert — (a) no record → summon shows one notice, creates nothing; (b) Post records then summon focuses the open window (assert via `win_findbuf`); (c) window closed (buffer deleted) → summon reopens the temp file via `:pedit`; (d) missing outfile → one WARN notice, no buffer; (e) Pre-without-Post (running) → no-op notice; (f) idempotency — repeated summons converge on the same window with no new buffers (scenarios per `quickstart.md` and FR-005/006/003/004/008/014)
- [x] T008 [US1] Validate US1: `nvim --headless -u NORC -c 'lua require("tests.db_results_smoke")' -c 'qa!'` prints all `PASS` and exits 0; `stylua --check nvim` clean

**Checkpoint**: At this point, User Story 1 is fully functional and testable independently.

---

## Phase 4: User Story 2 - dadbod-ui notifications through native Neovim notifications (Priority: P2)

**Story Link**: [US2 in spec.md](./spec.md#user-story-2---dadbod-ui-notifications-through-native-neovim-notifications-priority-p2)

**Goal**: dadbod-ui execution notices (info/warning/error, including "Executing query...") appear in the native Neovim notification area (Snacks) instead of the bottom-left overlay, via the upstream `g:db_ui_use_nvim_notify` option — config-only, no source edits, no new dependency.

**Independent Test**: `nvim --headless -u nvim/init.lua -c 'lua assert(vim.g.db_ui_use_nvim_notify, "db_ui_use_nvim_notify not set"); vim.print("PASS notify-routing")' -c 'qa!'`; interactive confirmation in `quickstart.md` US2.

### Implementation for User Story 2

- [x] T009 [US2] In the vim-dadbod-ui `on_setup` block of `nvim/plugin/database.lua` (where `db_ui_use_nerd_fonts`, `db_ui_save_location`, and the sybase table helper are set) add `vim.g.db_ui_use_nvim_notify = true` (FR-009/FR-010; Neovim-only per spec assumption; `g:db_ui_disable_info_notifications` behavior untouched, FR-011)
- [x] T010 [US2] Validate US2: run the full-config assert above plus `nvim --headless -u nvim/init.lua '+quitall'` (clean startup with the option); confirm native dadbod `DB: Query finished in …` cmdline echo and the progress float remain (documented limitation, unchanged)

**Checkpoint**: At this point, User Stories 1 AND 2 both work independently.

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Constitution obligations spanning both stories

- [x] T011 [P] Update `nvim/README.md` (FR-015, Module README gate XIV): document `<leader>qr` behavior (DB results group), the notification routing via `g:db_ui_use_nvim_notify`, the native dadbod echo limitation, and rollback (`git revert` of the Neovim-module changes; in-memory slot vanishes with the process, no state left behind)
- [x] T012 Run full verification gates (FR-014, Verification gate VIII): `nvim --headless -u nvim/init.lua '+quitall'`; `stylua --check nvim`; all db smokes — `tests.sybase_adapter_smoke`, `tests.sybase_objects_smoke`, `tests.db_objects_save_smoke`, `tests.db_jump_smoke`, `tests.db_results_smoke` via `nvim --headless -u NORC -c 'lua require("tests.<name>")' -c 'qa!'`
- [x] T013 Verify idempotency / non-destructive / recovery (gates II/III/X): repeated `<leader>qr` presses converge on the same buffer/window — no duplicates accumulate; summon paths never create files or mutate query state; rollback documented in `nvim/README.md` (T011) matches actual `git revert` behavior
- [ ] T014 Feature-branch/PR discipline (gate XIII): commit conventionally on `006-dbui-query-results` (never `main`); submit PR linking the approved issue; before PR creation verify the active spec relationship (this spec = completed solution) and ask whether `specs/006-dbui-query-results` should be closed

**Checkpoint**: All user stories independently functional; all constitution gates pass.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — branch + tracking first.
- **Foundational (Phase 2)**: Depends on Setup; T003 blocks US1.
- **US1 (Phase 3)**: Depends on T003; `T004 → T008` sequential in-file (`db_results.lua`), `T005`/`T007` parallel (other files); `T006` precedes US2's `T009` because both edit `nvim/plugin/database.lua`.
- **US2 (Phase 4)**: Independent of US1 (different file surface: `plugin/database.lua` option + full-config validation); can run in parallel with US1 implementation.
- **Polish (Phase 5)**: Depends on US1 and US2 being complete.

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational; no dependency on US2.
- **User Story 2 (P2)**: Can start after Foundational; no dependency on US1 (only shares `nvim/plugin/database.lua`, so coordinate edits with T006).

### Parallel Opportunities

- T002 alone in Setup; T003 foundational is sequential.
- US1: T005 and T007 are `[P]` (distinct files) and can run while T004 is drafted.
- US1 vs US2: fully parallel teams — distinct stories, distinct files except `plugin/database.lua` (T006 then T009).
- Polish: T011 `[P]` runs while T012 validation prepares.

---

## Parallel Example: User Story 1

```bash
# Launch independent US1 tasks together (different files):
Task: "Register <leader>qr keymap in nvim/lua/config/keymaps.lua"   (T005)
Task: "Create nvim/lua/tests/db_results_smoke.lua"                   (T007)

# Meanwhile another lane finishes the summon core and validation:
Task: "Implement db_results.show() in nvim/lua/config/db_results.lua" (T004)
Task: "Wire db_results.setup() in nvim/plugin/database.lua"           (T006)
# then run the smoke + stylua gate                            (T008)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (branch `006-dbui-query-results`).
2. Complete Phase 2: Foundational (`db_results.lua` skeleton — CRITICAL, blocks US1).
3. Complete Phase 3: User Story 1 (summon + keymap + smoke).
4. **STOP and VALIDATE**: run `db_results_smoke` + `stylua --check nvim` + full headless startup.
5. Demo/deliver if ready (US1 alone fixes the reported defect).

### Incremental Delivery

1. Setup + Foundational → module records every finished query result (visible only via the smoke test).
2. Add US1 → `<leader>qr` summons the last result → validate (MVP).
3. Add US2 → dadbod-ui notices move to native notifications → validate headless assert.
4. Polish → README, full gate run, idempotency/recovery checks → PR.

### Parallel Team Strategy

With two developers: A takes US1 (`db_results.lua`, `keymaps.lua`, smoke), B takes US2 (`plugin/database.lua` option + assert) after T006 touchpoint; they integrate at the Phase 5 gate run.

---

## Notes

- `[P]` tasks = different files, no dependencies.
- `[US#]` tasks map to the linked story phase; update the phase `Story Link` if the `spec.md` heading changes.
- Each story is independently completable and testable via its headless command.
- Do NOT modify `nvim/plugin/editor.lua` — its pending which-key `<leader>q group = 'database'` change is a pre-existing, unrelated working-tree change.
- Commit after each task or logical group on `006-dbui-query-results`, never directly on `main`.
- Before creating a PR, verify whether the active spec is related and ask whether a related completed spec should be closed.
- Stop at any checkpoint to validate the story independently.