# Contract: Neovim Notification UX

This contract defines observable editor behavior for the unified notifications/messages feature. It is a UI/behavior contract rather than an HTTP or CLI API contract.

## Transient Notification Popup

**Given** a notification-worthy event occurs, **when** it is emitted through the unified flow, **then** the user sees a transient popup that:

- Uses one shared layout for `info`, `warn`, `error`, and LSP progress events.
- Shows severity, source/title when available, and concise message text.
- Appears without stealing editing focus.
- Keeps command-line interaction usable when the command line is active.
- Summarizes long stack traces rather than filling the editor view.

## Notification/Message History

**Given** notifications or editor messages occurred in the current session, **when** the user opens history, **then** the user sees a LazyVim-like picker surface that:

- Lists recent notifications and captured editor messages.
- Supports searching/filtering by message text and source context.
- Shows severity and relative ordering/time.
- Provides a detail preview for the selected entry.
- Handles empty history with clear feedback.

## Command Failure Reporting

**Given** a command or key-triggered action fails, **when** the failure is captured, **then** the user receives:

- A visible error notification within 2 seconds during normal interactive use.
- A concise summary of the failed action and high-level reason.
- Full details available through history or fallback message review.
- A still-usable editor session after the failure.

## LSP Progress Reporting

**Given** an LSP server emits progress or attach/failure feedback, **when** the event reaches the unified flow, **then** the user sees:

- A LazyVim-like progress notification with the client/source visible, such as `tsgo`.
- Updates that replace or refresh the related progress entry instead of creating noisy duplicates.
- A completion or failure state that is visible and reviewable.

## Fallback Behavior

**Given** Snacks notifier or picker is unavailable, **when** notifications or messages are emitted, **then** baseline Neovim feedback still works through `vim.notify`/`:messages` without startup failure.

## Out-of-Scope Guard

Diagnostic UI changes are not part of this contract. Inline diagnostics, current-line diagnostic styling, signs, and diagnostic navigation should remain unchanged except for preventing regressions caused by notification/message work.
