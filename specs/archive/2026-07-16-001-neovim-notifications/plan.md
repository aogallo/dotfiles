# Implementation Plan: Neovim Notifications

**Branch**: `001-neovim-notifications` | **Date**: 2026-07-16 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-neovim-notifications/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command; its definition describes the execution workflow.

## Summary

Route Neovim notifications through the already-installed Snacks notification utility so routine messages are visible outside the command line, reviewable through a notification history, and ready to support LSP progress feedback for issue #22. The implementation should extend the existing Snacks plugin declaration in `nvim/plugin/editor.lua`, expose a history command/keymap, and add a focused LSP progress bridge that emits progress updates through the same notification path.

## Technical Context

**Language/Version**: Lua for Neovim configuration; current Neovim runtime used by these dotfiles.

**Primary Dependencies**: `folke/snacks.nvim` already declared in `nvim/plugin/editor.lua`; Neovim built-in `vim.notify`, `LspProgress` autocmd, and LSP client APIs.

**Storage**: Session-scoped Snacks notification history; no persistent storage planned.

**Testing**: Manual Neovim smoke checks, Lua syntax/loading checks where available, and repeated startup validation to confirm no duplicate handlers.

**Target Platform**: Local Neovim environment managed by this dotfiles repository, primarily macOS.

**Project Type**: Dotfiles-managed Neovim configuration.

**Performance Goals**: Notifications appear promptly during editing; a burst of 10 notifications leaves editing responsive; LSP progress updates reuse one progress notification instead of flooding the UI.

**Constraints**: Must not steal focus, must remain idempotent across repeated config loads, must avoid destructive user configuration changes, and must degrade to baseline `vim.notify` behavior if Snacks is unavailable.

**Scale/Scope**: One Neovim notification experience covering ordinary notifications, session history, and LSP progress readiness.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Document how the plan satisfies each applicable dotfiles constitution gate:

- **Portability**: Uses existing Neovim plugin configuration and built-in editor events; no user-specific absolute paths or machine-specific assumptions.
- **Idempotency**: Plan requires a single notification setup path and a named LSP progress autocmd group so repeated loads do not duplicate handlers.
- **Non-destructive safety**: Extends the existing Snacks configuration instead of replacing unrelated user settings; fallback behavior keeps baseline notification usability.
- **Modularity**: Primary source changes should stay in Neovim plugin/LSP modules; unrelated tools remain untouched.
- **Source of truth**: Repository-managed Neovim files remain authoritative; no secrets, generated credentials, or local private files are introduced.
- **Dependencies**: Reuses already-installed `folke/snacks.nvim`; no new plugin dependency is required for this feature.
- **Security**: No secret handling or external data flow is introduced.
- **Verification**: Quickstart defines visible notification, history, LSP progress, burst, and repeated-startup checks.
- **Installer UX**: No installer changes are required; existing package update flow should continue installing Snacks as declared.
- **Recovery**: Rollback is limited to reverting the Neovim configuration changes for this feature.
- **Maintainability**: Smallest practical change is preferred: configure Snacks notifier and add a focused LSP progress bridge only if needed.
- **Documentation**: Quickstart documents validation and troubleshooting expectations for notifications and history.
- **Branch/PR discipline**: Implementation should happen on the feature branch associated with this spec and link issue #22 when a PR is prepared.

Plans with unresolved MUST-level violations cannot proceed unless the violation is
explicitly documented as a constitutional exception with rationale and risk.

## Project Structure

### Documentation (this feature)

```text
specs/001-neovim-notifications/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
nvim/
├── init.lua
├── lua/
│   ├── config/
│   │   └── keymaps.lua
│   ├── lsp.lua
│   └── vim-pack.lua
├── lsp/
│   └── eslint.lua
└── plugin/
    └── editor.lua

specs/001-neovim-notifications/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
└── contracts/
    └── notification-experience.md
```

**Structure Decision**: Keep notification plugin setup with the existing Snacks declaration in `nvim/plugin/editor.lua`; keep LSP progress integration near existing LSP behavior in `nvim/lua/lsp.lua`; add user access to history through the existing keymap/group conventions.

## Complexity Tracking

No constitution violations require complexity justification.

## Phase 0 Research Summary

See [research.md](./research.md). Key decision: use the existing `folke/snacks.nvim` dependency and its `notifier` utility as the notification surface, with `Snacks.notifier.show_history()` as the history entry point and `vim.notify` as the compatibility bridge.

## Phase 1 Design Summary

See [data-model.md](./data-model.md), [contracts/notification-experience.md](./contracts/notification-experience.md), and [quickstart.md](./quickstart.md). The design models notifications, notification history, and progress events as session-scoped editor concepts rather than persisted application data.

## Post-Design Constitution Check

No new constitutional violations were introduced by Phase 1 design. The design remains modular, idempotent, non-destructive, dependency-light, and manually verifiable.
