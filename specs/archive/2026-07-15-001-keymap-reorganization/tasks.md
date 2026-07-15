# Tasks: Neovim Keymap Reorganization

**Input**: Design documents from `/Users/allan/dotfiles/specs/001-keymap-reorganization/`
**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/keymap-inventory.md`, `quickstart.md`
**Tests**: Formal TDD tasks are not included; validation tasks come from `quickstart.md` and the constitution.

## Phase 1: Setup

**Purpose**: Confirm the implementation surface and branch discipline before editing Neovim configuration.

- [x] T001 Verify work is on feature branch `001-keymap-reorganization` before editing files in `/Users/allan/dotfiles`
- [x] T002 Read approved migrations and preservations in `/Users/allan/dotfiles/specs/001-keymap-reorganization/contracts/keymap-inventory.md`
- [x] T003 [P] Inspect current keymap definitions in `/Users/allan/dotfiles/nvim/lua/config/keymaps.lua`, `/Users/allan/dotfiles/nvim/lua/lsp.lua`, `/Users/allan/dotfiles/nvim/plugin/diffview.lua`, `/Users/allan/dotfiles/nvim/plugin/editor.lua`, `/Users/allan/dotfiles/nvim/plugin/fzf-lua.lua`, `/Users/allan/dotfiles/nvim/plugin/gitsigns.lua`, and `/Users/allan/dotfiles/nvim/plugin/markdown.lua`

---

## Phase 2: Foundational

**Purpose**: Resolve blocking requirements and prevent stale or duplicate mapping work.
**CRITICAL**: No user story work can begin until this phase is complete.

- [x] T004 Confirm Markdown preview final destination is `<leader>up` in `/Users/allan/dotfiles/specs/001-keymap-reorganization/spec.md`
- [x] T005 Confirm document diagnostics picker final destination is `<leader>sd` in `/Users/allan/dotfiles/specs/001-keymap-reorganization/spec.md`
- [x] T006 [P] Confirm `/Users/allan/dotfiles/specs/001-keymap-reorganization/contracts/keymap-inventory.md` matches final `<leader>up` and `<leader>sd` destinations
- [x] T007 Build a one-pass edit checklist from required migrations in `/Users/allan/dotfiles/specs/001-keymap-reorganization/contracts/keymap-inventory.md`

**Checkpoint**: Foundation ready - user story implementation can now begin.

---

## Phase 3: US1 - Apply the Approved Semantic Mapping Proposal (Priority: P1) MVP

**Goal**: Every migrated leader mapping uses the approved semantic destination.
**Independent Test**: Compare affected files with `contracts/keymap-inventory.md` and confirm each required migration has exactly one final active mapping.

- [x] T008 [US1] Move base mappings `gQ` to `<leader>cf`, `H` to `<leader>bp`, `L` to `<leader>bn`, and `<leader>ps` to `<leader>pl` in `/Users/allan/dotfiles/nvim/lua/config/keymaps.lua`
- [x] T009 [P] [US1] Move LSP mappings `<leader>fs` to `<leader>cs` and `<leader>cl` to `<leader>cL` in `/Users/allan/dotfiles/nvim/lua/lsp.lua`
- [x] T010 [P] [US1] Move explorer mapping `<leader>e` to `<leader>fe` in `/Users/allan/dotfiles/nvim/plugin/editor.lua`
- [x] T011 [P] [US1] Move picker mappings to `<leader>bb`, `<leader>sb`, `<leader>sg`, `<leader>sh`, `<leader>sr`, `<leader>sd`, and `<leader>uh` in `/Users/allan/dotfiles/nvim/plugin/fzf-lua.lua`
- [x] T012 [P] [US1] Move git mappings `<leader>gc` to `<leader>gy`, `<leader>go` to `<leader>gO`, `<leader>gf` to `<leader>gh`, and `<leader>G*` to `<leader>gx*` in `/Users/allan/dotfiles/nvim/plugin/gitsigns.lua` and `/Users/allan/dotfiles/nvim/plugin/diffview.lua`
- [x] T013 [P] [US1] Move Markdown preview toggle `<leader>cp` to `<leader>up` in `/Users/allan/dotfiles/nvim/plugin/markdown.lua`

**Checkpoint**: US1 delivers the MVP semantic leader layout.

---

## Phase 4: US2 - Preserve Fast Editing Habits (Priority: P2)

**Goal**: High-frequency native-style and context-local mappings remain usable after migration.
**Independent Test**: Exercise preserved mappings listed in `quickstart.md` without relying on old moved leader shortcuts.

- [x] T014 [US2] Preserve insert escape, movement, paste, visual indent, and window navigation mappings in `/Users/allan/dotfiles/nvim/lua/config/keymaps.lua`
- [x] T015 [P] [US2] Preserve `[e`, `]e`, `gd`, `gD`, `grr`, `gy`, and `grc` LSP/diagnostic mappings in `/Users/allan/dotfiles/nvim/lua/lsp.lua`
- [x] T016 [P] [US2] Preserve `[g` and `]g` git hunk navigation in `/Users/allan/dotfiles/nvim/plugin/gitsigns.lua`
- [x] T017 [P] [US2] Preserve panel-local Diffview mappings that are only meaningful inside Diffview UI in `/Users/allan/dotfiles/nvim/plugin/diffview.lua`

**Checkpoint**: US2 keeps daily editing and navigation muscle memory intact.

---

## Phase 5: US3 - Make Discovery Consistent in Which-Key (Priority: P3)

**Goal**: Which-key presents every active leader namespace by user intent.
**Independent Test**: Open `<leader>` discovery and confirm buffers, code, files, git, packages, search, UI, and windows are visible with no stale orphan groups.

- [x] T018 [US3] Add or update top-level group labels for `<leader>b`, `<leader>c`, `<leader>f`, `<leader>g`, `<leader>p`, `<leader>s`, `<leader>u`, and `<leader>w` in `/Users/allan/dotfiles/nvim/plugin/editor.lua`
- [x] T019 [US3] Audit and remove stale top-level discovery groups that no longer match active leader namespaces in `/Users/allan/dotfiles/nvim/plugin/editor.lua`
- [x] T020 [P] [US3] Ensure descriptions for moved picker mappings describe user intent rather than plugin implementation in `/Users/allan/dotfiles/nvim/plugin/fzf-lua.lua`
- [x] T021 [P] [US3] Ensure descriptions for moved git and Markdown mappings match their final groups in `/Users/allan/dotfiles/nvim/plugin/gitsigns.lua`, `/Users/allan/dotfiles/nvim/plugin/diffview.lua`, and `/Users/allan/dotfiles/nvim/plugin/markdown.lua`

**Checkpoint**: US3 makes the reorganized layout discoverable through which-key.

---

## Final Phase: Polish

**Purpose**: Validate the completed Neovim keymap reorganization and document the changed behavior.

- [x] T022 Run the headless Neovim configuration load check described in `/Users/allan/dotfiles/specs/001-keymap-reorganization/quickstart.md`
- [x] T023 Inspect active normal and visual mappings for duplicates listed in `/Users/allan/dotfiles/specs/001-keymap-reorganization/quickstart.md`
- [x] T024 Manually smoke test which-key discovery plus preserved and migrated mappings from `/Users/allan/dotfiles/specs/001-keymap-reorganization/quickstart.md`
- [x] T025 Document moved mappings, preserved mappings, validation results, and rollback path in `/Users/allan/dotfiles/specs/001-keymap-reorganization/verify-report.md`
- [x] T026 Validate the final diff has no secrets, user-specific absolute paths, or machine-specific assumptions in `/Users/allan/dotfiles/nvim/lua/config/keymaps.lua`, `/Users/allan/dotfiles/nvim/lua/lsp.lua`, `/Users/allan/dotfiles/nvim/plugin/diffview.lua`, `/Users/allan/dotfiles/nvim/plugin/editor.lua`, `/Users/allan/dotfiles/nvim/plugin/fzf-lua.lua`, `/Users/allan/dotfiles/nvim/plugin/gitsigns.lua`, and `/Users/allan/dotfiles/nvim/plugin/markdown.lua`
- [x] T027 Count active leader mappings and document whether at least 90% use semantic top-level groups in `/Users/allan/dotfiles/specs/001-keymap-reorganization/verify-report.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies; can start immediately.
- **Foundational (Phase 2)**: Depends on Setup; blocks all user story work.
- **US1 (Phase 3)**: Depends on Foundational; MVP implementation scope.
- **US2 (Phase 4)**: Depends on Foundational; can run alongside US1 if edits do not conflict.
- **US3 (Phase 5)**: Depends on Foundational; should be finalized after US1 destinations are in place.
- **Polish (Final Phase)**: Depends on all selected user stories being complete.

### User Story Dependencies

- **US1 (P1)**: No dependency on US2 or US3 after Foundational.
- **US2 (P2)**: No dependency on US1, but must be rechecked after migrated mappings are edited.
- **US3 (P3)**: Depends on final mapping destinations from US1 for accurate discovery labels.

### Parallel Opportunities

- T003 can run after T001 and T002 because it only inspects files.
- T006 can run in parallel with T004 and T005 because it checks the contract file.
- T009, T010, T011, T012, and T013 can run in parallel because they edit different source files.
- T015, T016, and T017 can run in parallel because they validate preserved mappings in different files.
- T020 and T021 can run in parallel after T018 establishes group labels.

---

## Parallel Example: User Story 1

```bash
Task: "Move LSP mappings in /Users/allan/dotfiles/nvim/lua/lsp.lua"
Task: "Move picker mappings in /Users/allan/dotfiles/nvim/plugin/fzf-lua.lua"
Task: "Move Markdown preview mapping in /Users/allan/dotfiles/nvim/plugin/markdown.lua"
```

## Parallel Example: User Story 2

```bash
Task: "Preserve LSP/diagnostic mappings in /Users/allan/dotfiles/nvim/lua/lsp.lua"
Task: "Preserve git hunk navigation in /Users/allan/dotfiles/nvim/plugin/gitsigns.lua"
Task: "Preserve panel-local mappings in /Users/allan/dotfiles/nvim/plugin/diffview.lua"
```

## Parallel Example: User Story 3

```bash
Task: "Ensure picker descriptions in /Users/allan/dotfiles/nvim/plugin/fzf-lua.lua"
Task: "Ensure git and Markdown descriptions in /Users/allan/dotfiles/nvim/plugin/gitsigns.lua, /Users/allan/dotfiles/nvim/plugin/diffview.lua, and /Users/allan/dotfiles/nvim/plugin/markdown.lua"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup.
2. Complete Phase 2: Foundational.
3. Complete Phase 3: US1 semantic mapping migrations.
4. Stop and validate US1 against `/Users/allan/dotfiles/specs/001-keymap-reorganization/contracts/keymap-inventory.md`.

### Incremental Delivery

1. Setup + Foundational: clarified, ready source of truth.
2. US1: approved mapping destinations are active.
3. US2: preserved mappings confirmed stable.
4. US3: which-key discovery aligned.
5. Polish: quickstart validation and rollback documentation complete.

### Task Counts

- **Total tasks**: 27
- **US1**: 6 tasks
- **US2**: 4 tasks
- **US3**: 4 tasks

## Notes

- `[P]` tasks touch different files or are read-only checks and can be performed in parallel after dependencies are satisfied.
- Setup, Foundational, and Polish tasks intentionally have no `[US#]` marker.
- User story tasks intentionally include `[US1]`, `[US2]`, or `[US3]` markers.

## Phase 6: Convergence

- [x] T028 Perform and document the interactive which-key discovery smoke test for buffers, code, files, git, packages, search, UI, and windows in `/Users/allan/dotfiles/specs/001-keymap-reorganization/verify-report.md` per SC-004 and US3/AC1 (partial)
