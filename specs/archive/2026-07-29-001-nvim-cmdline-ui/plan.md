# Implementation Plan: Neovim Command-Line UI

**Branch**: `001-nvim-cmdline-ui` | **Date**: 2026-07-28 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-nvim-cmdline-ui/spec.md`

## Summary

Improve the repository-managed Neovim UI so normal command entry uses a centered floating command-line interface, command options align to the input width, and normal messages/notifications no longer rely on the bottom command-line area. The recommended direction is approval-gated: use Noice for command-line, command popupmenu, message routing, and LSP progress; keep existing Snacks modules for input/select/notifier history unless Noice notification routing requires disabling Snacks notifier; do not add Dressing because it is archived and does not solve command-line mode; do not add Fidget initially unless Noice LSP progress cannot match the expected unobtrusive progress style.

Implementation MUST NOT begin until the user approves the selected provider decision documented in [research.md](./research.md).

## Technical Context

**Language/Version**: Lua configuration for Neovim; current external candidate requirements include Neovim 0.9+ for Noice and Neovim 0.11.3+ for current Fidget releases.

**Primary Dependencies**: Existing `vim-pack` plugin manager, existing `folke/snacks.nvim`, existing `ibhagwan/fzf-lua`, existing custom `notifications` module; candidate dependency `folke/noice.nvim`; candidate transitive rendering dependency `MunifTanjim/nui.nvim`; optional/fallback candidate `j-hui/fidget.nvim` only if Noice LSP progress is rejected after review.

**Storage**: Repository-managed Neovim config files and `nvim/nvim-pack-lock.json`; notification runtime history remains in memory during Neovim sessions.

**Testing**: Neovim headless startup smoke test, Lua formatting check via `stylua --check nvim`, dependency validation via `setup/validate-nvim-deps.sh`, manual interactive validation for command-line popup/completion/notification behavior, and repeated-start smoke validation.

**Target Platform**: Portable macOS dotfiles for Neovim on supported Apple Silicon and Intel Macs.

**Project Type**: Dotfiles configuration module.

**Performance Goals**: Command-line popup appears immediately during interactive use; notification/progress UI appears within the spec threshold of 1 second for LSP progress and clears within 5 seconds after completion.

**Constraints**: No user-specific absolute paths, no secrets, no direct commits to `main`, no overlapping active notification providers unless explicitly justified, and no implementation before user approval of the provider decision.

**Scale/Scope**: One Neovim module change touching command-line UI, message/notification routing, LSP progress display, plugin lock state, docs, and validation artifacts.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Portability**: PASS. Plan uses repository-relative Neovim config and standard Neovim runtime/plugin mechanisms; no machine-specific paths are required.
- **Idempotency**: PASS. Implementation tasks must avoid duplicate `vim.notify` wrappers, duplicate LSP handlers, and duplicate message routes across repeated startup.
- **Non-destructive safety**: PASS. No user-owned files are replaced by this config change; rollback is removing/disabling the added plugin/config and restoring prior notification behavior.
- **Modularity**: PASS. Scope is limited to the Neovim module and does not require tmux, Ghostty, installer, or shell module changes.
- **Source of truth**: PASS. Shared behavior lives in committed Neovim config and plugin lock files; runtime notification history remains local memory only.
- **Dependencies**: PASS with task obligation. Any added plugin must be declared through `vim-pack`, locked in `nvim/nvim-pack-lock.json`, and documented in `nvim/README.md`.
- **Security**: PASS. No credentials, tokens, or private paths are involved.
- **Verification**: PASS with task obligation. Plan defines headless startup, formatting, dependency validation, manual UI checks, and repeated startup checks.
- **Installer UX**: NOT APPLICABLE. This feature does not alter installer output or install flow.
- **Recovery**: PASS. Rollback is documented as disabling/removing the new command-line/message provider config and restoring prior Snacks/custom notification behavior.
- **Maintainability**: PASS. Noice is preferred over custom UI because it directly covers the command-line/message domain; custom UI is rejected as higher maintenance.
- **Documentation**: PASS with task obligation. `nvim/README.md` must document usage, validation, troubleshooting, and rollback.
- **Module README**: PASS with task obligation. The existing `nvim/README.md` must be updated in the implementation PR.
- **Spec navigation**: PASS with task obligation. `/speckit.tasks` must include marker legend and user-story links.
- **Branch/PR discipline**: PASS with task obligation. Work must occur on a feature branch, link approved issue #62, and ask about spec closure before PR creation.

No constitutional exceptions are required.

## Project Structure

### Documentation (this feature)

```text
specs/001-nvim-cmdline-ui/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── ui-behavior.md
└── tasks.md
```

### Source Code (repository root)

```text
nvim/
├── init.lua
├── nvim-pack-lock.json
├── README.md
├── lua/
│   ├── notifications.lua
│   └── statusline.lua
└── plugin/
    ├── editor.lua
    └── blink.lua

setup/
└── validate-nvim-deps.sh
```

**Structure Decision**: Keep the change inside the existing Neovim module. Add or adjust plugin configuration in `nvim/plugin/editor.lua` because Snacks and notification wiring already live there. Preserve insert-mode completion in `nvim/plugin/blink.lua`; only revisit `cmdline` behavior if the approved provider requires it. Keep notification history/fallback logic centralized in `nvim/lua/notifications.lua`. Update `nvim/README.md` for module-level operational docs.

## Complexity Tracking

No constitutional violations or complexity exceptions are required.

## Phase 0: Research Output

Research is captured in [research.md](./research.md). The recommended approval-gated decision is Noice for command-line, popupmenu, messages, and LSP progress, with Snacks retained for existing non-conflicting modules and notification history unless the implementation proves a conflict.

## Phase 1: Design Output

- Data model: [data-model.md](./data-model.md)
- UI behavior contract: [contracts/ui-behavior.md](./contracts/ui-behavior.md)
- Validation guide: [quickstart.md](./quickstart.md)

## Post-Design Constitution Check

- **Portability**: PASS. Design remains repository-relative and portable.
- **Idempotency**: PASS. UI provider state and notification routing include duplicate-handler prevention as required behavior.
- **Non-destructive safety**: PASS. Rollback and fallback behavior are documented.
- **Modularity**: PASS. Design remains limited to Neovim module paths.
- **Source of truth**: PASS. Runtime state is not committed; plugin lock is the dependency source of truth.
- **Dependencies**: PASS. Added provider dependency must be declared and locked during implementation.
- **Security**: PASS. No secret-bearing configuration is introduced.
- **Verification**: PASS. Quickstart defines startup, format, dependency, manual UI, and repeated-start validation.
- **Installer UX**: NOT APPLICABLE.
- **Recovery**: PASS. Quickstart includes rollback checks.
- **Maintainability**: PASS. Custom UI is deferred/rejected unless the approved provider fails acceptance criteria.
- **Documentation**: PASS with implementation obligation.
- **Module README**: PASS with implementation obligation.
- **Spec navigation**: PASS with `/speckit.tasks` obligation.
- **Branch/PR discipline**: PASS with PR obligation.

No unresolved NEEDS CLARIFICATION markers remain.
