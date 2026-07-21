# Tasks: Markdown Notes Formatting

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 80-140 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | ask-on-risk |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Formatter selection and docs | PR 1 | Small single-review change |

## Phase 1: Setup and Baseline

- [x] T001 Verify implementation branch is not `main` before editing `nvim/plugin/conform.lua` or `nvim/README.md`.
- [x] T002 Inspect Markdown, `_`, and `prettier` entries in `nvim/plugin/conform.lua`.
- [x] T003 Confirm `nvim/dependencies.tsv` changes are unnecessary unless dependency meaning changes.

## Phase 2: User Story 1 - Notes-Only Saves (P1) MVP

**Goal**: Notes-only Markdown saves without Prettier/no-formatter errors.

- [x] T004 [US1] Add a portable Markdown formatter decision helper in `nvim/plugin/conform.lua` using local config signals, not notes paths.
- [x] T005 [US1] Update `markdown` in `nvim/plugin/conform.lua` to use Prettier for configured projects and safe trim fallback or quiet skip for notes-only folders.
- [x] T006 [US1] Preserve `vim.g.autoformat`, `vim.g.skip_formatting`, Java, and minifiles guards in `nvim/plugin/conform.lua`.
- [x] T007 [US1] Validate Scenario 1 in `specs/001-markdown-notes-formatting/quickstart.md` with a temp notes-only `note.md`.
- [x] T008 [US1] Validate Scenario 5 in `specs/001-markdown-notes-formatting/quickstart.md` by repeatedly saving temp `note.md`.

## Phase 3: User Story 2 - Lightweight Notes Folders (P2)

**Goal**: Document Obsidian-style notes without required Node/project tooling.

- [x] T009 [US2] Add notes-folder guidance to `nvim/README.md`: Markdown files plus optional vault-local settings are enough.
- [x] T010 [US2] Document in `nvim/README.md` that package manifests, Prettier config, and formatter deps are optional opt-ins.
- [x] T011 [US2] Add rollback guidance in `nvim/README.md` for reverting `nvim/plugin/conform.lua` and README changes.
- [x] T012 [US2] Validate Scenario 2 in `specs/001-markdown-notes-formatting/quickstart.md` with temp `note.md` plus vault settings.

## Phase 4: User Story 3 - Project Markdown Regression (P3)

**Goal**: Configured project Markdown still uses Prettier; autoformat still controls saves.

- [x] T013 [US3] Keep `formatters.prettier = { require_cwd = true }` and unrelated formatter entries unchanged in `nvim/plugin/conform.lua`.
- [x] T014 [US3] Validate Scenario 3 in `specs/001-markdown-notes-formatting/quickstart.md` with a temp Markdown project containing formatter config.
- [x] T015 [US3] Validate Scenario 4 in `specs/001-markdown-notes-formatting/quickstart.md` by setting `vim.g.autoformat = false` before save.

## Phase 5: Static, Headless, and PR Readiness

- [x] T016 Run `stylua --check nvim` from `/Users/allan/dotfiles`.
- [x] T017 Run `nvim --headless -u nvim/init.lua '+quitall'` from `/Users/allan/dotfiles`.
- [x] T018 Run `setup/validate-nvim-deps.sh` from `/Users/allan/dotfiles`; verify `nvim/dependencies.tsv` remains accurate.
- [x] T019 Before PR creation, review `specs/001-markdown-notes-formatting/spec.md` and ask whether to close/archive it.

## Dependencies & Execution Order

Phase 1 -> US1 MVP -> US2 docs -> US3 regression -> Phase 5 validation.
