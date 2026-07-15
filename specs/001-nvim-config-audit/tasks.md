# Tasks: Neovim Config Audit

**Input**: Design documents from `/specs/001-nvim-config-audit/`
**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/audit-report.md`
**Tests**: Constitution validation and quickstart commands are required.

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 180-260 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR: audit report + validation evidence |
| Delivery strategy | ask-on-risk |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Produce documentation-backed Neovim audit report | PR 1 | Read-only audit artifact; no config fixes |

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Confirm inputs, scope, and report target.

- [x] T001 Verify required artifacts exist with `test -f specs/001-nvim-config-audit/{spec.md,plan.md,research.md,data-model.md,contracts/audit-report.md}`.
- [x] T002 Verify audit scope exists with `test -f nvim/init.lua`, `test -d nvim/lua`, `test -d nvim/plugin`, `test -d nvim/lsp`, and `test -f nvim/nvim-pack-lock.json`.
- [x] T003 Create `specs/001-nvim-config-audit/audit-report.md` using the required sections from `specs/001-nvim-config-audit/contracts/audit-report.md`.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Build complete review inputs before judging findings.

- [x] T004 Inventory every file under `nvim/init.lua`, `nvim/lua/**`, `nvim/plugin/**`, `nvim/lsp/**`, `nvim/ftplugin/**`, `nvim/after/**`, `nvim/snippets/**`, `nvim/nvim-pack-lock.json`, and `nvim/stylua.toml` into the report coverage table.
- [x] T005 Query Context7 or primary docs for Neovim v0.12.1 APIs used by `nvim/lua/vim-pack.lua`, `nvim/lua/lsp.lua`, and `nvim/init.lua`; record source URLs/IDs in `audit-report.md`.
- [x] T006 Query plugin-specific docs for `nvim/plugin/treesitter.lua`, `blink.lua`, `conform.lua`, `fzf-lua.lua`, `mason.lua`, `markdown.lua`, `gitsigns.lua`, `snacks.nvim`, and `obsidian.nvim`; record evidence in `audit-report.md`.
- [x] T007 Extract all LSP server commands from `nvim/lsp/*.lua` into the dependency inventory with executable, source, install hint, and validation command.
- [x] T008 Extract formatters, linters, parsers, plugin-managed assets, snippet tools, and CLI integrations from `nvim/plugin/**`, `nvim/snippets/**`, and `nvim/nvim-pack-lock.json`.

**Checkpoint**: Foundation complete; user stories can be reviewed independently.

---

## Phase 3: User Story 1 - Audit Neovim Configuration Correctness (Priority: P1) 🎯 MVP

**Goal**: Document correctness of major Neovim subsystems with evidence-backed findings.
**Independent Test**: Every major subsystem has status, evidence, and action when needed.

- [x] T009 [US1] Review startup and built-in plugin management in `nvim/init.lua` and `nvim/lua/vim-pack.lua`; add coverage rows and findings.
- [x] T010 [US1] Review LSP, diagnostics, and server config in `nvim/lua/lsp.lua` and `nvim/lsp/*.lua`; classify findings as correct, deprecated, incompatible, risk, or improvement.
- [x] T011 [US1] Review Treesitter behavior in `nvim/plugin/treesitter.lua`; classify parser install, highlighting, folding, query path, and indentation risks.
- [x] T012 [US1] Review completion and snippets in `nvim/plugin/blink.lua` and `nvim/snippets/**`; document correctness and cleanup needs.
- [x] T013 [US1] Review formatting and lint integration in `nvim/plugin/conform.lua`; verify formatter list semantics and classify findings.
- [x] T014 [US1] Review diagnostics/editor integrations in `nvim/plugin/editor.lua`, `fzf-lua.lua`, `gitsigns.lua`, `schemastore.lua`, and `markdown.lua`.
- [x] T015 [US1] Confirm `audit-report.md` findings include ID, severity, classification, location, observation, impact, recommendation, and validation.

**Checkpoint**: MVP audit report is independently reviewable for correctness.

---

## Phase 4: User Story 2 - Identify Portable Dependency Strategy (Priority: P2)

**Goal**: Classify all required and optional Neovim dependencies for future installation.
**Independent Test**: Every referenced external tool has a declared source and validation path.

- [x] T016 [US2] Classify each dependency in `audit-report.md` as `mason`, `external`, `plugin-managed`, `homebrew`, `language-toolchain`, `optional`, or `unresolved`.
- [x] T017 [US2] Document external LSP fallback strategy for `nvim/lsp/gopls.lua`, `tsgo.lua`, `dprint.lua`, `ty.lua`, and other non-Mason executables.
- [x] T018 [US2] Add portable install hints for macOS Apple Silicon and Intel where dependency source differs.
- [x] T019 [US2] Add validation commands for each required dependency and explicit non-blocking behavior for optional dependencies.

**Checkpoint**: Dependency inventory can seed installer planning without re-audit.

---

## Phase 5: User Story 3 - Prepare for Reproducible Dotfiles Installation (Priority: P3)

**Goal**: Frame recommendations around portability, safety, rollback, and maintainability.
**Independent Test**: Recommendations map to follow-up installer tasks without guessing safety requirements.

- [x] T020 [US3] Flag user-specific or work-specific settings in `nvim/plugin/markdown.lua` and `nvim/plugin/gitsigns.lua` in Findings or justify portability.
- [x] T021 [US3] Complete Installer Readiness checklist in `audit-report.md` for portability, idempotency, safety, dependency declaration, secrets, validation, and rollback.
- [x] T022 [US3] Separate must-fix recommendations from optional improvements in `audit-report.md`, including validation method for each must-fix item.
- [x] T023 [US3] Document open questions only when code and docs cannot resolve a recommendation.

**Checkpoint**: All user stories are independently reviewable.

---

## Phase 6: Polish & Cross-Cutting Validation

**Purpose**: Prove report completeness and constitution compliance.

- [x] T024 Run `stylua --check nvim`; record failures as formatting findings instead of silently fixing them.
- [x] T025 Run `nvim --headless -u nvim/init.lua '+quitall'`; record startup result in `audit-report.md`.
- [x] T026 Run `nvim --headless -u nvim/init.lua '+checkhealth vim.lsp' '+checkhealth nvim-treesitter' '+checkhealth mason' '+quitall'`; classify missing optional tools.
- [x] T027 Validate contract acceptance: every `nvim/` Lua file is in coverage, every `nvim/lsp/*.lua` has dependency rows, high/critical findings have validation, and machine-specific settings are handled.
- [x] T028 Validate constitution gates in `audit-report.md`: portability, idempotency, safety, modularity, source of truth, dependencies, security, verification, installer UX, recovery, simplicity, and documentation.

## Dependencies & Execution Order

- Phase 1 → Phase 2 → US1 MVP → US2 → US3 → Polish.
- US1 is MVP and can stop after T015 if only correctness audit is needed.
- US2 and US3 depend on the inventories from T004-T008 but remain independently reviewable.
