# Tasks: Neovim Notifications

**Input**: Design documents from `/specs/001-neovim-notifications/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/notification-experience.md, quickstart.md

**Tests**: No TDD or automated test suite was explicitly requested. Validation tasks are included for Neovim startup, notification behavior, history behavior, LSP progress readiness, burst handling, and repeated-startup idempotency.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel because it touches different files or has no dependency on incomplete tasks
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- Every task includes exact repository-relative file paths

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Confirm the existing Neovim/Snacks baseline and preserve the current active Spec Kit context before implementation.

- [x] T001 Inspect the current Snacks plugin declaration and existing options in `nvim/plugin/editor.lua`
- [x] T002 Inspect existing notification call sites that should flow through `vim.notify` in `nvim/lsp/eslint.lua` and `nvim/lua/config/autocmds.lua`
- [x] T003 Inspect existing keymap group conventions for UI commands in `nvim/lua/config/keymaps.lua` and `nvim/plugin/editor.lua`
- [x] T004 Confirm the active feature pointer remains `specs/001-neovim-notifications` in `.specify/feature.json`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Configure the shared notification foundation that all user stories depend on.

**Critical**: No user story work can begin until this phase is complete.

- [x] T005 Enable and configure the Snacks notifier option in the existing `folke/snacks.nvim` spec in `nvim/plugin/editor.lua`
- [x] T006 Configure Snacks notifier display defaults for severity visibility, readable width/height, timeout, and non-focus-stealing behavior in `nvim/plugin/editor.lua`
- [x] T007 Ensure the notifier setup preserves `vim.notify` compatibility for existing notification call sites in `nvim/plugin/editor.lua`
- [x] T008 Add defensive fallback behavior for unavailable Snacks notifier functionality in `nvim/plugin/editor.lua`

**Checkpoint**: Foundation ready; visible notifications, history access, and LSP progress integration can now be implemented.

---

## Phase 3: User Story 1 - See Important Notifications While Editing (Priority: P1) MVP

**Goal**: Normal Neovim notifications appear in a visible notification surface outside the command line without stealing editing focus.

**Independent Test**: Trigger an informational, warning, and error notification during editing and confirm each appears outside the command line while editing focus remains intact.

### Implementation for User Story 1

- [x] T009 [US1] Add a manual visible-notification smoke command or documented command example for `vim.notify` in `specs/001-neovim-notifications/quickstart.md`
- [x] T010 [US1] Validate existing `vim.notify` call sites route to the Snacks notifier without direct call-site rewrites in `nvim/lsp/eslint.lua` and `nvim/lua/config/autocmds.lua`
- [x] T011 [US1] Tune notification severity icons or visual distinction through Snacks notifier options in `nvim/plugin/editor.lua`
- [x] T012 [US1] Run a Neovim startup smoke check for notification configuration using `nvim/init.lua`
- [x] T013 [US1] Validate informational, warning, and error visible notification scenarios from `specs/001-neovim-notifications/quickstart.md`

**Checkpoint**: User Story 1 should be fully functional and testable independently as the MVP.

---

## Phase 4: User Story 2 - Review Notification History Clearly (Priority: P2)

**Goal**: The user can open a readable session notification history without relying on noisy raw command messages.

**Independent Test**: Trigger several notifications, open notification history, and confirm recent messages are readable, ordered, and easier to scan than raw command output.

### Implementation for User Story 2

- [x] T014 [US2] Add a user-facing notification history keymap or command that calls `Snacks.notifier.show_history()` in `nvim/plugin/editor.lua`
- [x] T015 [US2] Register the notification history action with the existing UI-related keymap discoverability conventions in `nvim/plugin/editor.lua`
- [x] T016 [US2] Add empty-history and noisy-message validation steps to `specs/001-neovim-notifications/quickstart.md`
- [x] T017 [US2] Validate session-scoped notification history behavior from `specs/001-neovim-notifications/quickstart.md`

**Checkpoint**: User Stories 1 and 2 should both work independently.

---

## Phase 5: User Story 3 - Understand LSP Startup Progress (Priority: P3)

**Goal**: LSP startup and progress events use the same notification experience and remain reviewable through notification history.

**Independent Test**: Open a project that starts a configured language server and confirm begin, completion, or failure progress feedback appears through the same notification surface and history.

### Implementation for User Story 3

- [x] T018 [US3] Add a named LSP progress autocmd group for notification progress handling in `nvim/lua/lsp.lua`
- [x] T019 [US3] Implement `LspProgress` handling that aggregates progress by client/token and emits a stable `vim.notify` progress notification in `nvim/lua/lsp.lua`
- [x] T020 [US3] Add safe handling for missing clients or malformed progress payloads in `nvim/lua/lsp.lua`
- [x] T021 [US3] Ensure completed LSP progress resolves cleanly and remains reviewable through notifier history in `nvim/lua/lsp.lua`
- [x] T022 [US3] Document one supported LSP progress validation scenario in `specs/001-neovim-notifications/quickstart.md`
- [x] T023 [US3] Validate LSP progress start, completion, and failure/readability expectations from `specs/001-neovim-notifications/quickstart.md`

**Checkpoint**: All user stories should now be independently functional.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final validation, documentation, and safety checks across all stories.

- [x] T024 [P] Run Lua/Neovim syntax or startup validation for `nvim/plugin/editor.lua` and `nvim/lua/lsp.lua`
- [x] T025 [P] Validate burst handling with 10 quick notifications using `specs/001-neovim-notifications/quickstart.md`
- [x] T026 [P] Validate repeated-startup idempotency using `specs/001-neovim-notifications/quickstart.md`
- [x] T027 [P] Update troubleshooting notes for missing Snacks notifier or command-line fallback behavior in `specs/001-neovim-notifications/quickstart.md`
- [x] T028 Review notification requirement checklist outcomes in `specs/001-neovim-notifications/checklists/notifications.md`
- [x] T029 Confirm no unrelated Neovim plugin behavior was changed in `nvim/plugin/editor.lua`, `nvim/lua/lsp.lua`, `nvim/lsp/eslint.lua`, and `nvim/lua/config/autocmds.lua`
- [x] T030 Verify implementation work is on the feature branch and PR preparation links issue #22 before closure review in `specs/001-neovim-notifications/plan.md`
- [x] T031 Validate notifications emitted during early startup do not break Neovim startup using `nvim/init.lua`
- [x] T032 Validate notification history remains session-scoped and does not imply persistence across restarts using `specs/001-neovim-notifications/quickstart.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies; can start immediately.
- **Foundational (Phase 2)**: Depends on Setup completion; blocks all user stories.
- **User Story 1 (Phase 3)**: Depends on Foundational; MVP scope.
- **User Story 2 (Phase 4)**: Depends on Foundational and benefits from User Story 1, but remains independently testable through history scenarios.
- **User Story 3 (Phase 5)**: Depends on Foundational and benefits from User Story 1's `vim.notify` bridge, but remains independently testable with LSP progress scenarios.
- **Polish (Phase 6)**: Depends on completed desired user stories.

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational; no dependency on US2 or US3.
- **User Story 2 (P2)**: Can start after Foundational; uses the same notifier foundation and can be validated with manually triggered notifications.
- **User Story 3 (P3)**: Can start after Foundational; uses the same notifier foundation and can be validated with LSP progress events.

### Within Each User Story

- Configure or implement the minimal behavior first.
- Update quickstart validation only when the user-facing behavior exists.
- Validate the story independently before moving to the next priority.

### Parallel Opportunities

- Setup inspection tasks T001, T002, and T003 can be split across agents, but their findings should be reconciled before T005.
- After T005-T008 complete, US2 history work and US3 LSP progress work can proceed in parallel because they primarily touch different files.
- Polish validation tasks T024-T027 can run in parallel after the relevant implementation tasks are complete.

---

## Parallel Example: User Story 2

```text
Task: "Add a user-facing notification history keymap or command that calls Snacks.notifier.show_history() in nvim/plugin/editor.lua"
Task: "Add empty-history and noisy-message validation steps to specs/001-neovim-notifications/quickstart.md"
```

## Parallel Example: User Story 3

```text
Task: "Implement LspProgress handling that aggregates progress by client/token and emits a stable vim.notify progress notification in nvim/lua/lsp.lua"
Task: "Document one supported LSP progress validation scenario in specs/001-neovim-notifications/quickstart.md"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup.
2. Complete Phase 2: Foundational notifier configuration.
3. Complete Phase 3: visible notifications while editing.
4. Stop and validate User Story 1 independently with informational, warning, and error notifications.

### Incremental Delivery

1. Add User Story 1 to move routine notifications out of the command line.
2. Add User Story 2 to provide notification history and recovery from missed messages.
3. Add User Story 3 to connect LSP progress to the same notification path.
4. Complete Phase 6 validations and checklist review.

### Parallel Team Strategy

1. Complete Setup and Foundational tasks together.
2. Split history access work and LSP progress work after the notifier foundation is stable.
3. Reconcile quickstart validation and final polish before PR preparation.

---

## Notes

- `[P]` tasks touch different files or can run after implementation without blocking each other.
- `[US1]`, `[US2]`, and `[US3]` labels map directly to the user stories in `spec.md`.
- Commit after logical work units on the feature branch, never directly on `main`.
- Before creating a PR, verify whether the active spec is related to the PR and ask whether the completed spec should be closed.

---

## Phase 7: Convergence

- [x] T033 Add generic LSP failure notification coverage with client name, severity, concise reason when available, and history visibility in `nvim/lua/lsp.lua` and `specs/001-neovim-notifications/quickstart.md` per FR-006a (partial)
