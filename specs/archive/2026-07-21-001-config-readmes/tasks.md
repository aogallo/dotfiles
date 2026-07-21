# Tasks: Configuration README Documentation

**Input**: Design documents from `/specs/001-config-readmes/`
**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/documentation-review.md`, `quickstart.md`

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 120-220 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | single-pr |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

## Phase 1: Setup (Documentation Inspection)

**Purpose**: Confirm current docs and config before editing.

- [x] T001 Inspect tmux behaviors and plugins in `Tmux/tmux.conf`
- [x] T002 [P] Inspect current Neovim documentation sections in `nvim/README.md`
- [x] T003 [P] Inspect root README tmux/Neovim setup guidance in `README.md`

---

## Phase 2: Foundational (Documentation Boundaries)

**Purpose**: Prevent duplicated or misleading setup guidance.

- [x] T004 Compare `specs/001-config-readmes/contracts/documentation-review.md` against `Tmux/tmux.conf`, `nvim/README.md`, and `README.md`
- [x] T005 Decide whether `README.md` needs only links to directory docs or no change based on contradiction review in `README.md`

**Checkpoint**: Documentation scope and source-of-truth boundaries are clear.

---

## Phase 3: User Story 1 - Understand tmux configuration quickly (Priority: P1) 🎯 MVP

**Goal**: `Tmux/README.md` explains purpose, setup, TPM, reload, validation, and main behaviors.
**Independent Test**: Open only `Tmux/README.md` and identify purpose/setup/plugin/reload/key behaviors in under 2 minutes.

- [x] T006 [US1] Create `Tmux/README.md` with a short purpose statement and quick path for activating `Tmux/tmux.conf`
- [x] T007 [US1] Document TPM prerequisite and plugin install/update flow in `Tmux/README.md`
- [x] T008 [US1] Document terminal colors, mouse, vi copy mode, pane split/navigation, reload, session cleanup, and scratch popup behavior in `Tmux/README.md`
- [x] T009 [US1] Document safe validation and rollback guidance for local tmux activation in `Tmux/README.md`

**Checkpoint**: US1 works independently as the MVP.

---

## Phase 4: User Story 2 - Recognize Neovim as shared configuration (Priority: P1)

**Goal**: `nvim/README.md` remains concise and clearly frames Neovim as shared config.
**Independent Test**: Open `nvim/README.md` and find purpose, validation, dependencies, linking, notifications, Obsidian, and local overrides in under 3 minutes.

- [x] T010 [US2] Refine the opening and quick path wording in `nvim/README.md` only where needed to emphasize shared configuration
- [x] T011 [US2] Preserve validation, dependency strategy, linking, notifications, Obsidian, and local override guidance in `nvim/README.md`
- [x] T012 [US2] Add or adjust rollback/customization guidance in `nvim/README.md` only if missing after review

**Checkpoint**: US2 remains independently reviewable.

---

## Phase 5: User Story 3 - Avoid duplicate or misleading setup instructions (Priority: P2)

**Goal**: Root README does not contradict directory-level documentation.
**Independent Test**: Compare `README.md`, `Tmux/README.md`, and `nvim/README.md` and find no conflicting setup instructions.

- [x] T013 [US3] Replace stale tmux details with a pointer to `Tmux/README.md` if contradictions exist in `README.md`
- [x] T014 [US3] Replace stale Neovim setup/linking details with a pointer to `nvim/README.md` if contradictions exist in `README.md`
- [x] T015 [US3] Verify root README remains an overview and does not duplicate full directory setup details in `README.md`

**Checkpoint**: Documentation source-of-truth boundaries are consistent.

---

## Final Phase: Polish & Cross-Cutting Validation

- [x] T016 Run documentation review scenarios from `specs/001-config-readmes/quickstart.md`
- [x] T017 Run safe command checks from `specs/001-config-readmes/quickstart.md`
- [x] T018 Verify no private paths, secrets, or work-specific values were added to `Tmux/README.md`, `nvim/README.md`, or `README.md`
- [x] T019 Verify active spec relationship and ask whether `specs/001-config-readmes` should be closed before PR creation

---

## Dependencies & Execution Order

- Phase 1 has no dependencies; T002 and T003 can run in parallel with T001.
- Phase 2 depends on Phase 1 and blocks all user stories.
- US1 is the MVP because `Tmux/` currently lacks a README.
- US2 can run after Phase 2 and should preserve existing Neovim docs.
- US3 depends on US1 and US2 because it compares root README against directory docs.
- Final validation depends on completed documentation changes.

## Parallel Opportunities

- T002 and T003 can run while T001 inspects `Tmux/tmux.conf`.
- T010 can run after Phase 2 while T006-T009 are reviewed if file edits stay separate.
- T013 and T014 can be reviewed together after US1 and US2 are complete, but edits to `README.md` should be sequential.

## Parallel Example

```text
Task: "T002 [P] Inspect current Neovim documentation sections in nvim/README.md"
Task: "T003 [P] Inspect root README tmux/Neovim setup guidance in README.md"
```

## Implementation Strategy

### MVP Scope

Complete Phases 1-3 only: add `Tmux/README.md` with safe setup, validation, and behavior guidance.

### Incremental Delivery

1. Inspect current config/docs and decide boundaries.
2. Deliver Tmux README as MVP.
3. Refine Neovim README only where needed.
4. Remove root README contradictions and run documentation validation.
