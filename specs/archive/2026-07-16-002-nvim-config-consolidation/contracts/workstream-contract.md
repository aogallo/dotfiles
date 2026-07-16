# Contract: Neovim Consolidation Workstream

Each consolidation workstream must satisfy this contract before merging into `feat/nvim-config-consolidation`.

## Required Metadata

| Field | Requirement |
|-------|-------------|
| Workstream | One of `options`, `keymaps`, `plugins`, `cleanup` |
| Branch | Conventional branch based on `feat/nvim-config-consolidation` |
| Target | `feat/nvim-config-consolidation` |
| Scope | Paths touched by the workstream |
| Migration decisions | Adopt/reject/defer notes for legacy behavior reviewed |
| Validation evidence | Commands/manual checks run and outcomes |

## Workstream Scope

| Workstream | Allowed Primary Paths | Required Decision Evidence |
|------------|-----------------------|----------------------------|
| Options | `nvim/lua/config/options.lua`, source option files | Option comparison and rationale for changes |
| Keymaps | `nvim/lua/config/keymaps.lua`, source keymap files | Conflict review for each added or changed mapping |
| Plugins | `nvim/plugin/`, `nvim/lsp/`, `nvim/dependencies.tsv`, source plugin files | Plugin purpose, overlap check, dependency impact |
| Cleanup | `lvim/`, `kickstart.nvim/`, `lazyvim/`, docs/spec notes | Confirmation relevant behavior was adopted, rejected, or deferred |

## Merge Preconditions

- The branch is based on `feat/nvim-config-consolidation`.
- The branch does not include unrelated workstream changes.
- Touched Lua files pass `stylua --check`.
- Relevant Neovim smoke or manual validation is recorded.
- Dependency changes are reflected in `nvim/dependencies.tsv` when applicable.
- Cleanup does not remove source material before migration decisions are recorded.
- The PR links an approved issue if repository workflow requires it.

## Final Integration Preconditions

- All four workstreams are merged into `feat/nvim-config-consolidation` or explicitly deferred by the user.
- `nvim/` is identifiable as the canonical Neovim config.
- Legacy config cleanup status is clear.
- The active spec relationship is checked before the final PR to `main`.
- The user is asked whether `specs/002-nvim-config-consolidation/` should be archived if the final PR completes the spec.
