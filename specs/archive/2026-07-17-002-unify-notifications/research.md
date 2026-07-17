# Research: Unify Neovim Notifications

## Decision: Use Snacks notifier as the primary visible notification surface

**Rationale**: The existing configuration already enables `folke/snacks.nvim` notifier in `nvim/plugin/editor.lua`. Snacks notifier supports severity icons, timeout, width/height, margins, compact style, and stores notifications in history. This aligns with the desired LazyVim-like transient popup without introducing another dependency.

**Alternatives considered**: Add a new notification plugin; rejected because it increases dependency surface and risks conflicting with the existing Snacks setup. Use only Neovim default messages; rejected because the default `vim.notify` behavior falls back to the message area and does not meet the desired visual UX.

## Decision: Use Snacks picker/history for notification and message review

**Rationale**: Snacks exposes notification history through `Snacks.notifier.show_history()` and picker-style notification history through `Snacks.picker.notifications(opts?)` with severity formatting and preview support. This directly matches the requested searchable LazyVim-like history/detail UX.

**Alternatives considered**: Build a custom scratch buffer for history; rejected because Snacks already provides picker/history primitives. Rely on raw `:messages`; rejected because it is not searchable/detail-preview oriented and keeps the user in the command-message model the feature is meant to avoid.

## Decision: Preserve `vim.notify` as the canonical notification entry point

**Rationale**: Neovim documents `vim.notify` as extensible and overrideable by notification providers. Existing call sites already use `vim.notify` for LSP attach/progress/failure and plugin messages. Keeping it canonical minimizes call-site churn and keeps fallback behavior available when Snacks is unavailable.

**Alternatives considered**: Replace all notification call sites with direct Snacks calls; rejected because direct calls make fallback harder and couple unrelated modules to Snacks internals.

## Decision: Bridge editor messages into the unified review experience without persistent storage

**Rationale**: Neovim keeps message history available via `:messages`, while Snacks notifier stores `vim.notify` events. The feature needs ordinary editor messages to be reviewable in the same UX, but the spec limits history to the current session. A small bridge can normalize selected editor messages into notification/history entries while preserving raw `:messages` fallback.

**Alternatives considered**: Persist messages across restarts; rejected because the spec explicitly scopes history to the current session. Replace Neovim message handling globally; rejected as too broad and risky for command-line/editor behavior.

## Decision: Keep LSP progress notifications based on `LspProgress` events

**Rationale**: Neovim documents `LspProgress` as the event for monitoring LSP progress, and the current configuration already uses it to emit stable `vim.notify` updates with an `id` per client. Planning should refine formatting/UX, not replace the event source.

**Alternatives considered**: Poll LSP client state; rejected because event-driven progress already exists and is more accurate. Move progress to statusline only; rejected because the feature asks for LazyVim-like notifications.

## Decision: Keep diagnostics UI out of this feature

**Rationale**: Diagnostics presentation is related visually but has different interaction surfaces: inline text, current-line display, signs, virtual text, and navigation. The user selected a separate issue/spec for diagnostics, so this feature only guards against notification changes regressing diagnostics.

**Alternatives considered**: Include diagnostics UI now; rejected because it would expand scope and make planning/testing too broad for the notification/message objective.

## Decision: Fix or guard statusline highlight lookup as part of command-failure validation if needed

**Rationale**: The reported `<leader>gd` failure surfaced a statusline crash where highlight foreground/background values can be nil. Even though statusline repair is not the user-facing feature, command failure validation must ensure such failures are either prevented or surfaced as readable notifications without breaking the editing session.

**Alternatives considered**: Ignore the underlying statusline error and only route errors to notifications; rejected because a crashing statusline can continue to disrupt redraw and obscure validation results.
