# Tasks: Unify Neovim Notifications

**Input**: `/Users/allan/dotfiles/specs/002-unify-notifications/plan.md`, `/Users/allan/dotfiles/specs/002-unify-notifications/spec.md`, optional design docs, and constitution.
**Tests**: Automated test creation is not required; use validation tasks from `/Users/allan/dotfiles/specs/002-unify-notifications/quickstart.md`.

## Phase 1: Setup

- [x] T001 Review Snacks notifier/picker entry points in `/Users/allan/dotfiles/nvim/plugin/editor.lua`
- [x] T002 [P] Review notification UX contract in `/Users/allan/dotfiles/specs/002-unify-notifications/contracts/neovim-notification-ux.md`
- [x] T003 [P] Review validation scenarios in `/Users/allan/dotfiles/specs/002-unify-notifications/quickstart.md`

---

## Phase 2: Foundational

- [x] T004 Create unified notification helper with safe notify, severity normalization, summary/detail handling, and history adapter in `/Users/allan/dotfiles/nvim/lua/notifications.lua`
- [x] T005 Add shared severity/progress icons for unified notifications in `/Users/allan/dotfiles/nvim/lua/icons.lua`
- [x] T006 Wire Snacks notifier, fallback handling, and searchable history mapping through the helper in `/Users/allan/dotfiles/nvim/plugin/editor.lua`
- [x] T007 Add idempotent message-capture autocmd/group setup that preserves `:messages` fallback in `/Users/allan/dotfiles/nvim/lua/config/autocmds.lua`

**Checkpoint**: Foundation ready; user stories can be implemented independently.

---

## Phase 3: User Story 1 - See Command Errors as Notifications (Priority: P1) 🎯 MVP

**Goal**: Command failures and editor messages appear through the unified notification/review path.
**Independent Test**: Run quickstart Scenario 3 and confirm the failure is visible as a concise error notification with detail review.

- [x] T008 [US1] Route captured editor error/warning/info messages to unified history and popup rules in `/Users/allan/dotfiles/nvim/lua/config/autocmds.lua`
- [x] T009 [US1] Wrap LSP definition keymap failures with concise unified error notifications in `/Users/allan/dotfiles/nvim/lua/lsp.lua`
- [x] T010 [US1] Guard nil statusline highlight values so command failure validation does not crash redraw in `/Users/allan/dotfiles/nvim/lua/statusline.lua`
- [x] T011 [US1] Preserve full command failure details while showing concise summaries in `/Users/allan/dotfiles/nvim/lua/notifications.lua`
- [x] T012 [US1] Validate quickstart command-failure scenario and record result in `/Users/allan/dotfiles/specs/002-unify-notifications/quickstart.md`

---

## Phase 4: User Story 2 - Get Consistent Severity Formatting (Priority: P2)

**Goal**: Info, warn, error, progress, and messages share one visual language and searchable detail preview.
**Independent Test**: Run quickstart Scenarios 1, 2, and 4.

- [x] T013 [US2] Configure Snacks notifier layout, timeout, dimensions, icons, and severity levels consistently in `/Users/allan/dotfiles/nvim/plugin/editor.lua`
- [x] T014 [US2] Prefer `Snacks.notifier.show_history()` with custom picker fallback for searchable detail preview in `/Users/allan/dotfiles/nvim/plugin/editor.lua`
- [x] T015 [US2] Normalize popup/history severity labels, source, title, and details for all entries in `/Users/allan/dotfiles/nvim/lua/notifications.lua`
- [x] T016 [US2] Align LSP attach/progress/failure notification titles, IDs, icons, and replacement behavior in `/Users/allan/dotfiles/nvim/lua/lsp.lua`
- [x] T017 [US2] Validate quickstart severity, history, and LSP scenarios in `/Users/allan/dotfiles/specs/002-unify-notifications/quickstart.md`

---

## Phase 5: User Story 3 - Preserve Editing Flow During Failures (Priority: P3)

**Goal**: Notifications remain non-blocking, idempotent, burst-safe, and diagnostics-neutral.
**Independent Test**: Run quickstart Scenarios 5, 6, and 7.

- [x] T018 [US3] Ensure notification display keeps command-line/editor focus usable via Snacks keep/fallback behavior in `/Users/allan/dotfiles/nvim/plugin/editor.lua`
- [x] T019 [US3] Add burst-safe dedupe/update limits for repeated progress and captured message entries in `/Users/allan/dotfiles/nvim/lua/notifications.lua`
- [x] T020 [US3] Verify diagnostic configuration remains unchanged except no-regression behavior in `/Users/allan/dotfiles/nvim/lua/lsp.lua`
- [x] T021 [US3] Validate burst, diagnostics no-regression, and repeated-load scenarios in `/Users/allan/dotfiles/specs/002-unify-notifications/quickstart.md`

---

## Final Phase: Polish & Cross-Cutting

- [x] T022 [P] Document notification history mapping, validation, and rollback notes in `/Users/allan/dotfiles/nvim/README.md`
- [x] T023 Run `stylua --check nvim` and headless Neovim startup/health validation from `/Users/allan/dotfiles/specs/002-unify-notifications/quickstart.md`
- [x] T024 Run Neovim dependency validation from `/Users/allan/dotfiles/setup/validate-nvim-deps.sh`
- [x] T025 Verify active spec relationship and PR closure-review requirement in `/Users/allan/dotfiles/specs/002-unify-notifications/spec.md`

---

## Dependencies & Execution Order

- Phase 1 has no dependencies.
- Phase 2 depends on Phase 1 and blocks all user stories.
- US1 is the MVP and should land first; US2 and US3 depend on the foundation and can be implemented after or alongside US1 if file conflicts are coordinated.
- Final polish depends on selected stories being complete.

### User Story Dependencies

- US1: depends only on Phase 2.
- US2: depends on Phase 2; integrates with US1 conventions but remains independently testable.
- US3: depends on Phase 2; validates non-blocking/idempotent behavior across prior stories.

## Parallel Execution Examples

### User Story 1

```text
Task: T009 in /Users/allan/dotfiles/nvim/lua/lsp.lua
Task: T010 in /Users/allan/dotfiles/nvim/lua/statusline.lua
```

### User Story 2

```text
Task: T015 in /Users/allan/dotfiles/nvim/lua/notifications.lua
Task: T016 in /Users/allan/dotfiles/nvim/lua/lsp.lua
```

### User Story 3

```text
Task: T018 in /Users/allan/dotfiles/nvim/plugin/editor.lua
Task: T020 in /Users/allan/dotfiles/nvim/lua/lsp.lua
```

## Implementation Strategy

### MVP First

Complete Phases 1-2, implement US1, then validate quickstart Scenario 3 before expanding scope.

### Incremental Delivery

Add US2 for consistent severity/history UX, then US3 for burst, focus, idempotency, and diagnostics no-regression.

### Task Counts

- Total: 25 tasks
- Setup: 3 tasks
- Foundational: 4 tasks
- US1: 5 tasks
- US2: 5 tasks
- US3: 4 tasks
- Polish: 4 tasks

---

## Phase 6: Convergence

- [x] T026 Wrap `<leader>gd`/Diffview command failures with unified action context in `/Users/allan/dotfiles/nvim/plugin/diffview.lua` per FR-002 and US1/AC3 (partial)
- [x] T027 Route remaining repo-owned direct `vim.notify` call sites through unified helper or merge their Snacks history into `/Users/allan/dotfiles/nvim/lua/notifications.lua` per FR-001, FR-011, and FR-012 (partial)
- [x] T028 Complete attached-UI manual validation for command failure, severity/history/LSP, burst, diagnostics no-regression, and repeated-load scenarios in `/Users/allan/dotfiles/specs/002-unify-notifications/quickstart.md` per FR-013 and SC-001..SC-009 (partial)
- [x] T029 Update notification history validation notes to match the implemented Snacks native history priority in `/Users/allan/dotfiles/specs/002-unify-notifications/quickstart.md` per plan: history UX decision (partial)
