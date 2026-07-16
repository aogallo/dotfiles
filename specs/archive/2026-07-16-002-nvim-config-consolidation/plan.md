# Implementation Plan: Neovim Config Consolidation

**Branch**: `feat/nvim-config-consolidation` | **Date**: 2026-07-16 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/002-nvim-config-consolidation/spec.md`

## Summary

Consolidate Neovim configuration by treating `nvim/` as the only maintained target and using `lvim/`, `kickstart.nvim/`, and `lazyvim/` as source material. The implementation will be split into four independently reviewable work units: options, keymaps, plugins, and cleanup. Work unit branches will target the integration branch `feat/nvim-config-consolidation`; after all work units are merged and verified, the integration branch will be merged to `main` through the normal PR flow.

## Technical Context

**Language/Version**: Lua for Neovim configuration; Markdown for Spec Kit artifacts; shell/GitHub CLI for validation and PR workflow.

**Primary Dependencies**: Neovim runtime, built-in package management via `packupdate`, existing `nvim/plugin/*.lua` plugin modules, existing `nvim/lsp/*.lua` configs, `stylua`, and dependencies declared in `nvim/dependencies.tsv`.

**Storage**: Repository files only. No database or external service storage.

**Testing**: `stylua --check` for touched Lua files, targeted `nvim --headless` smoke checks, dependency inventory review, manual quickstart validation, and Git diff/review checks for cleanup safety.

**Target Platform**: macOS dotfiles for Apple Silicon and Intel Macs where practical.

**Project Type**: Personal dotfiles repository with modular Neovim configuration.

**Performance Goals**: Neovim should start without configuration errors after each work unit; added plugins or tooling must have a clear workflow benefit and avoid duplicated heavy responsibilities.

**Constraints**: No direct implementation commits on `main`; no user-specific absolute paths, secrets, or local-only state; cleanup cannot remove legacy source material until migration decisions are recorded.

**Scale/Scope**: Four work units: options, keymaps, plugins/tooling, and legacy cleanup. Canonical target files live under `nvim/`; source material lives under `lvim/`, `kickstart.nvim/`, and `lazyvim/`.

## Branching And Work Unit Strategy

The consolidation uses one integration branch and four work-unit branches:

| Branch | Base | Target | Work Unit | Purpose |
|--------|------|--------|-----------|---------|
| `feat/nvim-config-consolidation` | `main` | `main` | Integration | Accumulates all approved work units before final merge to `main` |
| `feat/nvim-options-consolidation` | `feat/nvim-config-consolidation` | `feat/nvim-config-consolidation` | Options | Compare and migrate editor options deliberately |
| `feat/nvim-keymaps-consolidation` | `feat/nvim-config-consolidation` | `feat/nvim-config-consolidation` | Keymaps | Compare and migrate keymaps with conflict checks |
| `feat/nvim-plugins-consolidation` | `feat/nvim-config-consolidation` | `feat/nvim-config-consolidation` | Plugins | Review plugin/tooling overlap and dependency impact |
| `chore/nvim-legacy-cleanup` | `feat/nvim-config-consolidation` | `feat/nvim-config-consolidation` | Cleanup | Remove or archive stale legacy configs after decisions are recorded |

Each work-unit branch must be independently reviewable and include its own validation evidence. The cleanup branch runs last unless the user explicitly approves early removal of a clearly unrelated file. The final PR from `feat/nvim-config-consolidation` to `main` must verify active spec closure.

## Constitution Check

*GATE: Passed before Phase 0 research. Re-check after Phase 1 design: Passed.*

- **Portability**: The plan targets shared repo configuration only. New behavior must avoid user-specific absolute paths and use Neovim/runtime discovery or documented dependencies.
- **Idempotency**: Work units must preserve repeatable Neovim setup and avoid duplicated plugin declarations, duplicate keymaps, duplicate dependency rows, or generated state committed to the repo.
- **Non-destructive safety**: Cleanup is a separate final work unit. Legacy files are not removed until migration decisions are recorded and review confirms the material is no longer needed.
- **Modularity**: Work is split by responsibility: `nvim/lua/config/options.lua`, `nvim/lua/config/keymaps.lua`, `nvim/plugin/`, `nvim/lsp/`, `nvim/dependencies.tsv`, and legacy directories.
- **Source of truth**: `nvim/` is the maintained source of truth. `lvim/`, `kickstart.nvim/`, and `lazyvim/` are source material only until cleanup.
- **Dependencies**: Any required or optional tool changes must update `nvim/dependencies.tsv` or be documented as intentionally unnecessary.
- **Security**: No credentials, tokens, local private paths, machine identifiers, or work-only configuration may be migrated.
- **Verification**: Each work unit requires formatting checks for touched Lua files and targeted Neovim smoke/manual validation relevant to its scope.
- **Installer UX**: If setup or dependency validation behavior changes, skipped/missing optional tools must be reported clearly and not block unrelated editor startup.
- **Recovery**: All removals are recoverable through Git history and are isolated in the cleanup branch. No user-owned external Neovim config is modified.
- **Maintainability**: Existing `nvim/` structure is preferred; new helpers or plugins require a concrete workflow benefit.
- **Documentation**: This plan, research, data model, contracts, quickstart, and later tasks must record migration decisions and validation paths.
- **Branch/PR discipline**: Implementation happens on work-unit branches based on `feat/nvim-config-consolidation`; the final integration PR to `main` verifies the active spec relationship and asks whether the completed spec should be archived.

No constitutional violations are identified.

## Project Structure

### Documentation (this feature)

```text
specs/002-nvim-config-consolidation/
├── plan.md
├── research.md
├── data-model.md
├── migration-decisions.md
├── quickstart.md
├── contracts/
│   └── workstream-contract.md
└── tasks.md
```

### Source Code (repository root)

```text
nvim/
├── dependencies.tsv
├── lua/config/
│   ├── options.lua
│   └── keymaps.lua
├── lsp/
│   └── *.lua
└── plugin/
    └── *.lua

lvim/
└── config.lua

kickstart.nvim/
├── lua/config/
│   ├── options.lua
│   └── keymaps.lua
└── lua/custom/plugins/
    └── *.lua

lazyvim/
├── lua/config/
│   ├── options.lua
│   └── keymaps.lua
└── lua/plugins/
    └── *.lua
```

**Structure Decision**: Keep `nvim/` as the canonical maintained config. Use the legacy directories only for comparison during options, keymaps, and plugin work units; remove or archive them only in the cleanup work unit after migration decisions are recorded.

## Complexity Tracking

No constitutional violations require complexity exceptions.

## Phase 0 Output

Research is captured in [research.md](./research.md).

## Phase 1 Output

Design artifacts are captured in:

- [data-model.md](./data-model.md)
- [migration-decisions.md](./migration-decisions.md)
- [contracts/workstream-contract.md](./contracts/workstream-contract.md)
- [quickstart.md](./quickstart.md)
