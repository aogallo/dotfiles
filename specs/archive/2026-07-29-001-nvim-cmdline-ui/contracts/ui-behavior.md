# UI Behavior Contract: Neovim Command-Line UI

## Scope

This contract defines observable behavior for the Neovim command-line UI feature. It is not an API contract; it is the behavioral contract that implementation and verification must satisfy.

## Command Entry

- Starting normal command entry opens a centered floating input.
- Command mode remains visible through the existing statusline.
- The bottom command-line area is not used as the normal command-entry surface.
- Submit and cancel close the floating input without leaving stale windows.
- Search, command history, filter, Lua, help, and input prompts remain usable or have documented fallback behavior.

## Command Options

- Command options appear visually attached to the floating command input.
- The option menu width uses at least 90% of the intended command input width in tested scenarios.
- Short option labels do not cause a narrow detached menu.
- The option list remains readable at 80, 120, and 160 terminal columns.
- Insert-mode completion remains unchanged by this feature.

## Notifications and Messages

- Informational, warning, error, and progress messages appear outside the bottom command-line area.
- Warnings and errors remain prominent and readable.
- Normal notifications do not duplicate across multiple visible providers.
- At least the latest 20 notifications/messages are discoverable through a documented history action.
- If the primary provider fails, messages still have a safe fallback path.

## LSP Progress

- LSP progress appears unobtrusively as floating feedback.
- Progress appears within 1 second of tested progress events.
- Completed progress clears within 5 seconds unless it reports an error.
- Idle Neovim sessions do not show stale progress UI.

## Provider Ownership

- The implementation must document which provider owns command-line input, command options, visible notifications, notification history, and LSP progress.
- Superseded provider behavior must be disabled or removed in the same work unit.
- Implementation must not proceed until the user approves the provider decision.
