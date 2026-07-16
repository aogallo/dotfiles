# Research: Neovim Notifications

## Decision: Use Snacks Notifier As The Notification Surface

**Rationale**: `folke/snacks.nvim` is already declared in `nvim/plugin/editor.lua`, so the feature can reuse an installed dependency instead of adding a new notification plugin. Snacks provides a `notifier` utility with configurable display behavior, stores notifications in history, and exposes `Snacks.notifier.show_history()` for review.

**Alternatives considered**: Add a dedicated notification plugin such as `nvim-notify`; keep relying on command-line messages and `:messages`; build a custom floating-window notification layer. These add dependency or maintenance cost and do not use the installed Snacks capability.

## Decision: Use `vim.notify` As The Compatibility Bridge

**Rationale**: Existing configuration already emits messages through `vim.notify` in places such as ESLint LSP handlers and autocmds. Routing `vim.notify` into Snacks keeps existing call sites working while moving user-visible output away from the command line.

**Alternatives considered**: Replace every notification call with direct `Snacks.notifier.notify` calls; keep both APIs side by side. Direct replacement is more invasive and easier to miss. Mixed APIs risk inconsistent history and display behavior.

## Decision: Expose History Through `Snacks.notifier.show_history()`

**Rationale**: Snacks documents `Snacks.notifier.show_history()` as the history entry point. This directly addresses the user's complaint that `:messages` is hard to scan when traces or noisy command output are present.

**Alternatives considered**: Use only `:messages`; create a custom message buffer; persist history to a file. These either preserve the original pain point or exceed the current session-scoped requirement.

## Decision: Implement LSP Progress With The `LspProgress` Event

**Rationale**: Snacks documentation shows an advanced LSP progress pattern based on Neovim's `LspProgress` autocmd and `vim.notify` with a stable `id = "lsp_progress"`. A stable notification ID lets progress update one visible notification instead of flooding the UI.

**Alternatives considered**: Ignore LSP progress until issue #22 implementation; emit every progress event as a separate notification; use only statusline indicators. Deferring leaves the foundation incomplete, separate notifications create noise, and statusline-only progress does not satisfy the notification-history goal.

## Decision: Keep History Session-Scoped

**Rationale**: The feature specification assumes session-scoped history. Snacks stores notification history for the editor session, which is enough to recover missed messages without introducing persistence, cleanup, or privacy concerns.

**Alternatives considered**: Persist notification history across restarts. Persistence is not required yet and would add scope around storage, retention, and sensitive message handling.

## Decision: Keep Changes Inside Existing Neovim Configuration Boundaries

**Rationale**: The repo already has a clear split between plugin setup in `nvim/plugin/editor.lua`, keymaps in `nvim/lua/config/keymaps.lua`, and LSP behavior in `nvim/lua/lsp.lua`. Keeping changes there preserves maintainability and avoids spreading notification logic into unrelated modules.

**Alternatives considered**: Create a new notification module immediately. A module may be useful if behavior grows, but the first implementation can stay smaller unless the code becomes hard to read.
