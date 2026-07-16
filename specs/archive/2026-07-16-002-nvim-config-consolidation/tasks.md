# Tasks: Neovim Config Consolidation

**Input**: `specs/002-nvim-config-consolidation/spec.md`, `plan.md`, `research.md`, `data-model.md`, `contracts/workstream-contract.md`, `quickstart.md`, `migration-decisions.md`, `.specify/memory/constitution.md`

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 600-1200 |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | options → keymaps → plugins → cleanup |
| Delivery strategy | auto-chain |
| Chain strategy | feature-branch-chain |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: feature-branch-chain
400-line budget risk: High

Rationale: The user explicitly selected a feature branch chain / principal branch model with work-unit branches targeting `feat/nvim-config-consolidation`.

### Suggested Work Units

| Unit | Branch | Target | Goal |
|------|--------|--------|------|
| 1 | `feat/nvim-options-consolidation` | `feat/nvim-config-consolidation` | Consolidate options into `nvim/lua/config/options.lua`. |
| 2 | `feat/nvim-keymaps-consolidation` | `feat/nvim-config-consolidation` | Consolidate keymaps into `nvim/lua/config/keymaps.lua`. |
| 3 | `feat/nvim-plugins-consolidation` | `feat/nvim-config-consolidation` | Consolidate plugins, LSP, and `nvim/dependencies.tsv`. |
| 4 | `chore/nvim-legacy-cleanup` | `feat/nvim-config-consolidation` | Remove legacy `lvim/`, `kickstart.nvim/`, and `lazyvim/` material after decisions. |

## Phase 1: Setup

- [x] T001 Verify current branch topology for `feat/nvim-config-consolidation` using `specs/002-nvim-config-consolidation/quickstart.md`.
- [x] T002 Create migration-decision notes in `specs/002-nvim-config-consolidation/migration-decisions.md` for options, keymaps, plugins, and cleanup evidence.

## Phase 2: Foundational

- [x] T003 Map canonical target paths `nvim/lua/config/options.lua`, `nvim/lua/config/keymaps.lua`, `nvim/plugin/`, `nvim/lsp/`, and `nvim/dependencies.tsv`.
- [x] T004 Map legacy source paths `lvim/config.lua`, `kickstart.nvim/lua/config/`, `kickstart.nvim/lua/custom/plugins/`, `lazyvim/lua/config/`, and `lazyvim/lua/plugins/`.
- [x] T005 Confirm no `.specify/extensions.yml` hooks are required for `specs/002-nvim-config-consolidation/tasks.md`.

## Phase 3: User Story 1 - Canonical Neovim Config (Priority: P1)

**Independent Test**: Confirm all maintained behavior changes target `nvim/` and legacy paths are only source material or cleanup scope.

- [x] T006 [US1] Record `nvim/` as the source of truth in `specs/002-nvim-config-consolidation/migration-decisions.md`.
- [x] T007 [P] [US1] Review canonical options ownership in `nvim/lua/config/options.lua` against `specs/002-nvim-config-consolidation/data-model.md`.
- [x] T008 [P] [US1] Review canonical keymaps ownership in `nvim/lua/config/keymaps.lua` against `specs/002-nvim-config-consolidation/data-model.md`.
- [x] T009 [P] [US1] Review canonical plugin ownership in `nvim/plugin/` and `nvim/lsp/` against `specs/002-nvim-config-consolidation/data-model.md`.
- [x] T010 [US1] Validate source-of-truth acceptance in `specs/002-nvim-config-consolidation/spec.md` before opening work-unit PRs.

## Phase 4: User Story 2 - Reviewable Workstreams (Priority: P1)

**Independent Test**: Validate each workstream has its own branch, scope, acceptance evidence, and validation path before implementation starts.

- [x] T011 [US2] Prepare options branch scope for `feat/nvim-options-consolidation` covering `nvim/lua/config/options.lua` and legacy option paths.
- [x] T012 [US2] Prepare keymaps branch scope for `feat/nvim-keymaps-consolidation` covering `nvim/lua/config/keymaps.lua` and legacy keymap paths.
- [x] T013 [US2] Prepare plugins branch scope for `feat/nvim-plugins-consolidation` covering `nvim/plugin/`, `nvim/lsp/`, and `nvim/dependencies.tsv`.
- [x] T014 [US2] Prepare cleanup branch scope for `chore/nvim-legacy-cleanup` covering `lvim/`, `kickstart.nvim/`, and `lazyvim/`.
- [x] T015 [US2] Verify each workstream satisfies `specs/002-nvim-config-consolidation/contracts/workstream-contract.md` before merge.

## Phase 5: User Story 3 - Preserve Editing Behavior Deliberately (Priority: P2)

**Independent Test**: Compare legacy configs against `nvim/` and ensure every adoption has rationale, dependency impact, and validation.

- [x] T016 [US3] Compare options from `lvim/config.lua`, `kickstart.nvim/lua/config/options.lua`, and `lazyvim/lua/config/options.lua` into `specs/002-nvim-config-consolidation/migration-decisions.md`.
- [x] T017 [US3] Apply adopted option decisions only to `nvim/lua/config/options.lua`.
- [x] T018 [US3] Validate options with `stylua --check nvim/lua/config/options.lua --config-path nvim/stylua.toml`.
- [x] T019 [US3] Compare keymaps from `lvim/config.lua`, `kickstart.nvim/lua/config/keymaps.lua`, and `lazyvim/lua/config/keymaps.lua` into `specs/002-nvim-config-consolidation/migration-decisions.md`.
- [x] T020 [US3] Apply non-conflicting keymap decisions only to `nvim/lua/config/keymaps.lua`.
- [x] T021 [US3] Validate keymaps with `stylua --check nvim/lua/config/keymaps.lua --config-path nvim/stylua.toml`.
- [x] T022 [US3] Compare plugin sources `lvim/config.lua`, `kickstart.nvim/lua/custom/plugins/`, and `lazyvim/lua/plugins/` into `specs/002-nvim-config-consolidation/migration-decisions.md`.
- [x] T023 [US3] Apply adopted plugin and LSP decisions to `nvim/plugin/`, `nvim/lsp/`, and `nvim/dependencies.tsv`.
- [x] T024 [US3] Validate plugins with `stylua --check nvim/plugin/*.lua nvim/lsp/*.lua --config-path nvim/stylua.toml`.
- [x] T025 [US3] Smoke-check canonical startup with `nvim --headless '+quitall'` from repo root `/Users/allan/dotfiles`.
- [x] T026 [US3] Inventory Markdown, TypeScript, Python, Serverless Framework, database, SQL, Docker, and Go workflow coverage in `specs/002-nvim-config-consolidation/migration-decisions.md`.
- [x] T027 [US3] Review `nvim/plugin/`, `nvim/lsp/`, `nvim/dependencies.tsv`, and `nvim/lua/config/keymaps.lua` for duplicate plugin, LSP, dependency, and keymap declarations.

## Phase 6: User Story 4 - Remove Legacy Config Drift Safely (Priority: P3)

**Independent Test**: Confirm cleanup is explicit, recoverable through Git, and happens only after migration decisions exist.

- [x] T028 [US4] Confirm options, keymaps, and plugins migration decisions exist in `specs/002-nvim-config-consolidation/migration-decisions.md` before cleanup.
- [x] T029 [US4] Review cleanup for already-deleted `kickstart.nvim/doc/kickstart.txt`, `kickstart.nvim/ftplugin/http.lua`, and `lazyvim/ftplugin/json.lua`.
- [x] T030 [US4] Document rollback and recovery steps for removed legacy config material in `specs/002-nvim-config-consolidation/migration-decisions.md`.
- [x] T031 [US4] Remove or archive approved legacy material under `lvim/`, `kickstart.nvim/`, and `lazyvim/`.
- [x] T032 [US4] Validate cleanup diff with `git diff -- lvim kickstart.nvim lazyvim specs/002-nvim-config-consolidation`.
- [x] T033 [US4] Validate post-cleanup source-of-truth and Neovim startup using `specs/002-nvim-config-consolidation/quickstart.md`.
- [x] T034 [US4] Ask whether `specs/002-nvim-config-consolidation/` should be archived before final PR to `main`.

## Phase 7: Polish & Final Integration

- [x] T035 Run final formatting with `stylua --check nvim/lua nvim/plugin nvim/lsp --config-path nvim/stylua.toml`.
- [x] T036 Run final smoke check with `nvim --headless '+quitall'` from repo root `/Users/allan/dotfiles`.
- [x] T037 Verify final integration branch status with `git status --short` on `feat/nvim-config-consolidation`.

## Dependencies & Execution Order

Setup and Foundational tasks precede all user stories. US1 and US2 are P1 and unblock scoped work. US3 runs options, keymaps, then plugins. US4 cleanup runs only after migration decisions are recorded. Polish runs after all selected work units merge into `feat/nvim-config-consolidation`.

## Parallel Opportunities

T007-T009 can run in parallel. T011-T014 can be prepared independently. Options, keymaps, and plugins branches can be reviewed independently if each remains scoped and targets `feat/nvim-config-consolidation`; cleanup must wait.

## Implementation Strategy

Use the feature-branch-chain/principal branch model: work-unit branches target `feat/nvim-config-consolidation`; then the integration branch targets `main`. Validate each work unit using `specs/002-nvim-config-consolidation/quickstart.md` before merge.
