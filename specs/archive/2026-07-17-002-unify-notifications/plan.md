# Implementation Plan: Unify Neovim Notifications

**Branch**: `002-unify-notifications` | **Date**: 2026-07-16 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/002-unify-notifications/spec.md`

## Summary

Unify Neovim user-facing feedback so `vim.notify` notifications, editor messages, command failures, and LSP progress use a consistent LazyVim-like experience: transient popup for important events plus searchable picker-style history with detail preview. The implementation will extend the existing Snacks notifier setup, add a small repository-owned notification/message bridge where Snacks does not already cover behavior, preserve existing LSP progress semantics, and explicitly leave diagnostic UI redesign to a separate feature.

## Technical Context

**Language/Version**: Lua for Neovim configuration; shell only for existing validation commands.

**Primary Dependencies**: Neovim built-in Lua APIs (`vim.notify`, `vim.api.nvim_create_autocmd`, `LspProgress`, `:messages`/message history), `folke/snacks.nvim` notifier and picker, existing `nvim-web-devicons`/Tokyonight highlights/icons.

**Storage**: Session-scoped in-memory notification/message history; no persisted storage.

**Testing**: `stylua --check nvim`, `nvim --headless -u nvim/init.lua '+quitall'`, `nvim --headless -u nvim/init.lua '+checkhealth vim.lsp' '+checkhealth nvim-treesitter' '+checkhealth mason' '+quitall'`, and manual interactive validation from `quickstart.md`.

**Target Platform**: Neovim on supported macOS dotfiles machines, portable across Apple Silicon and Intel where the existing Neovim setup is supported.

**Project Type**: Dotfiles-managed Neovim configuration.

**Performance Goals**: Visible notification appears within 2 seconds for command/keymap failures; notification/message history opens and finds a recent entry in under 10 seconds; burst of 10 mixed events keeps editing usable.

**Constraints**: No direct diagnostic UI redesign in this feature; no persisted history; no user-specific absolute paths; no duplicate handlers after repeated config loads; graceful fallback if Snacks notifier/picker is unavailable.

**Scale/Scope**: Single-user interactive editor session with recent notifications, editor messages, command failures, LSP attach/progress events, and mixed-severity bursts.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Portability**: Pass. Planned changes stay inside repository-managed Neovim Lua files and use Neovim runtime APIs, not user-specific absolute paths. Validation remains compatible with the existing macOS Neovim setup.
- **Idempotency**: Pass. Autocommands and handlers must use named augroups or guarded setup so repeated sourcing does not duplicate notifications or history entries.
- **Non-destructive safety**: Pass. The feature changes editor configuration only and must preserve fallback command-line/message visibility when optional UI pieces are unavailable.
- **Modularity**: Pass. Scope is limited to Neovim notification/message/LSP progress behavior; diagnostics UI is explicitly out of scope except regression avoidance.
- **Source of truth**: Pass. Shared behavior lives in repository-managed Neovim configuration; no generated state or local private values are introduced.
- **Dependencies**: Pass. Snacks.nvim already exists in `nvim/plugin/editor.lua`; no new dependency is required by the plan.
- **Security**: Pass. No secrets, credentials, private identifiers, or machine-specific values are introduced.
- **Verification**: Pass. Plan includes static formatting, headless startup/health checks, and manual interactive smoke scenarios for popup, history, command failure, LSP progress, message capture, burst handling, fallback, and diagnostics no-regression.
- **Installer UX**: Pass. No installer behavior changes are planned; validation docs will state expected outcomes and fallback behavior.
- **Recovery**: Pass. Rollback is reverting the Neovim configuration changes; no user-owned files or persisted data are modified.
- **Maintainability**: Pass. Prefer extending the existing Snacks notifier configuration and small focused Lua helpers over adding broad notification frameworks.
- **Documentation**: Pass. `quickstart.md` documents validation and expected behavior; README updates can be added during implementation if mappings or validation commands change.
- **Branch/PR discipline**: Pass. Work is on `002-unify-notifications`; PR creation must verify active spec relationship and ask whether this spec should close when complete.

## Project Structure

### Documentation (this feature)

```text
specs/002-unify-notifications/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── neovim-notification-ux.md
└── tasks.md
```

### Source Code (repository root)

```text
nvim/
├── plugin/
│   └── editor.lua          # Snacks notifier/picker configuration and user mappings
├── lua/
│   ├── lsp.lua             # LSP attach/progress/failure notification integration
│   ├── statusline.lua      # Reported command-failure source; must not crash notification flow
│   ├── icons.lua           # Existing icon source for severity styling
│   └── config/
│       └── autocmds.lua    # Existing command/user-message notification call sites
├── README.md               # Validation/mapping documentation if user-facing behavior changes
└── stylua.toml             # Lua formatting configuration
```

**Structure Decision**: Keep implementation inside the Neovim module. Extend `nvim/plugin/editor.lua` for Snacks notifier/history UX, keep LSP-specific notification logic in `nvim/lua/lsp.lua`, and add only minimal helper code if needed to bridge editor messages into the same history without broad cross-module rewrites.

## Phase 0: Research Summary

See [research.md](./research.md). All technical unknowns are resolved with no open clarification markers.

## Phase 1: Design Summary

See [data-model.md](./data-model.md), [contracts/neovim-notification-ux.md](./contracts/neovim-notification-ux.md), and [quickstart.md](./quickstart.md).

## Post-Design Constitution Check

- **Portability**: Pass. Design uses Neovim/Snacks APIs and repository-relative docs only.
- **Idempotency**: Pass. Contract requires named augroups/guarded setup and validation checks for duplicate handlers/messages.
- **Non-destructive safety**: Pass. No persisted storage or user-owned file writes are introduced.
- **Modularity**: Pass. Diagnostics UI remains a separate follow-up scope.
- **Source of truth**: Pass. All durable behavior is in repository-managed Neovim files.
- **Dependencies**: Pass. Uses existing Snacks.nvim dependency; no manifest change required unless implementation discovers a concrete gap.
- **Security**: Pass. No secret-bearing state is captured beyond normal editor message text already visible to the user.
- **Verification**: Pass. Quickstart covers automated checks plus manual end-to-end scenarios.
- **Installer UX**: Pass. No installer changes; docs provide clear expected outcomes.
- **Recovery**: Pass. Rollback is normal git/config revert.
- **Maintainability**: Pass. Small extension of existing configuration is preferred.
- **Documentation**: Pass. Quickstart is present; README update is deferred to implementation if key mappings or user commands change.
- **Branch/PR discipline**: Pass. Active spec is linked and must be reviewed before PR closure.

## Complexity Tracking

No constitutional violations or complexity exceptions are required.
