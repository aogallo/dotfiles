# Tasks: Obsidian Title-Based Filenames

**Input**: Design documents from `/specs/002-obsidian-title-filenames/`
**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/obsidian-note-creation.md`, `quickstart.md`

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 40-90 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | single-pr |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

## Phase 1: Setup (Shared Inspection)

**Purpose**: Confirm current config shape before editing.

- [x] T001 Inspect current Obsidian.nvim config, workspace path handling, and Markdown mappings in `nvim/plugin/markdown.lua`
- [x] T002 [P] Inspect current Which-Key leader groups and available `<leader>n` namespace in `nvim/plugin/editor.lua`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Preserve scoped, portable behavior before user-story work begins.

- [x] T003 Verify no new dependency or local vault path is needed by comparing `specs/002-obsidian-title-filenames/research.md` with `nvim/plugin/markdown.lua`
- [x] T004 [P] Verify user-facing Obsidian documentation location and current env-var notes in `nvim/README.md`

**Checkpoint**: Existing behavior and documentation boundaries are understood.

---

## Phase 3: User Story 1 - Create Notes With Recognizable Filenames (Priority: P1) 🎯 MVP

**Goal**: Titled Obsidian notes use title-derived IDs and filenames.
**Independent Test**: Create `AWS CodePipeline` with `:Obsidian new AWS CodePipeline` and confirm the Markdown filename is title-derived, not opaque.

- [x] T005 [US1] Configure `note_id_func = require('obsidian.builtin').title_id` in the Obsidian.nvim opts in `nvim/plugin/markdown.lua`
- [x] T006 [US1] Preserve `legacy_commands = false`, `snacks.picker`, and `OBSIDIAN_NOTES_DIR` workspace behavior in `nvim/plugin/markdown.lua`
- [x] T007 [P] [US1] Validate duplicate-title and no-title expectations against `specs/002-obsidian-title-filenames/quickstart.md`
- [x] T008 [US1] Manually run command scenario from `specs/002-obsidian-title-filenames/quickstart.md` for `:Obsidian new AWS CodePipeline`

**Checkpoint**: US1 works independently as the MVP.

---

## Phase 4: User Story 2 - Use a Discoverable Neovim Note Command (Priority: P2)

**Goal**: Note creation is discoverable under the semantic notes leader group.
**Independent Test**: Open `<leader>n`, see `notes`, trigger `<leader>nn`, enter a title, and confirm US1 filename behavior.

- [x] T009 [US2] Add Which-Key group `{ '<leader>n', group = 'notes' }` in `nvim/plugin/editor.lua`
- [x] T010 [US2] Add normal-mode mapping `<leader>nn` that opens `:Obsidian new ` with description `New note` in `nvim/plugin/markdown.lua`
- [x] T011 [P] [US2] Verify the mapping follows existing leader-domain conventions in `nvim/plugin/editor.lua`
- [x] T012 [US2] Manually run keymap scenario from `specs/002-obsidian-title-filenames/quickstart.md` for `<leader>nn`

**Checkpoint**: US2 is discoverable and produces the same note behavior as the command.

---

## Phase 5: User Story 3 - Preserve Safe Dotfiles Behavior (Priority: P3)

**Goal**: The change remains portable, scoped, idempotent, and reversible.
**Independent Test**: Review changed files and run validation commands without secrets, local paths, or duplicate mappings.

- [x] T013 [US3] Update `nvim/README.md` with title-based Obsidian filename behavior and `<leader>nn` if mappings changed
- [x] T014 [US3] Document rollback as reverting `nvim/plugin/markdown.lua`, `nvim/plugin/editor.lua`, and `nvim/README.md` in `nvim/README.md`
- [x] T015 [US3] Run repeated-load scenario from `specs/002-obsidian-title-filenames/quickstart.md` against `nvim/plugin/editor.lua` and `nvim/plugin/markdown.lua`
- [x] T016 [US3] Confirm no user-specific absolute paths, secrets, or unrelated module changes exist in `nvim/plugin/markdown.lua`, `nvim/plugin/editor.lua`, and `nvim/README.md`

**Checkpoint**: All safety and rollback expectations are reviewable.

---

## Final Phase: Polish & Cross-Cutting Validation

- [x] T017 Run formatting validation `stylua --check nvim` for `nvim/plugin/markdown.lua` and `nvim/plugin/editor.lua`
- [x] T018 Run headless startup validation `nvim --headless -u nvim/init.lua '+quitall'` for `nvim/init.lua`
- [x] T019 Run dependency validation `setup/validate-nvim-deps.sh` for `setup/validate-nvim-deps.sh`
- [x] T020 Verify branch/PR readiness and active spec linkage for `specs/002-obsidian-title-filenames/spec.md`

---

## Dependencies & Execution Order

- Phase 1 has no dependencies; T001 and T002 can run in parallel.
- Phase 2 depends on Phase 1 and blocks all user stories.
- US1 is the MVP and should be implemented before US2 because the mapping relies on title-based behavior.
- US2 depends on Phase 2 and integrates with US1 behavior.
- US3 can run after user-facing files are changed; Final Phase depends on selected stories being complete.

## Parallel Opportunities

- T002 and T004 can run while T001/T003 inspect different files.
- T007 can run after T005 while T006 is reviewed.
- T011 can run after T009 while T010 is implemented.
- T014 follows T013 because both update `nvim/README.md`.

## Parallel Example

```text
Task: "T002 [P] Inspect current Which-Key leader groups in nvim/plugin/editor.lua"
Task: "T004 [P] Verify user-facing Obsidian documentation location in nvim/README.md"
```

## Implementation Strategy

### MVP Scope

Complete Phases 1-3 only: title-derived filenames for `:Obsidian new [TITLE]` in `nvim/plugin/markdown.lua`.

### Incremental Delivery

1. Setup + Foundational inspection.
2. US1 title-based filenames and command smoke test.
3. US2 notes group and `<leader>nn` mapping.
4. US3 docs, rollback, idempotency, and full validation.
