# Quickstart: Neovim Command-Line UI Validation

## Prerequisites

- Work from the repository root.
- Use a feature branch for implementation work.
- Confirm issue #62 is approved before opening a PR.
- Confirm the user approved the provider decision from [research.md](./research.md) before implementation.

## Static Validation

Run the baseline Neovim startup check:

```sh
nvim --headless -u nvim/init.lua '+quitall'
```

Run formatting validation:

```sh
stylua --check nvim
```

Run dependency validation:

```sh
setup/validate-nvim-deps.sh
```

## Interactive Command-Line Validation

1. Open Neovim with the repository config.
2. Press `:` in a normal editing buffer.
3. Verify command entry appears in a centered floating input.
4. Verify the statusline shows command mode.
5. Verify the bottom command-line area is not the normal command-entry surface.
6. Cancel command entry and confirm no stale floating UI remains.
7. Submit a harmless command such as `:set number?` and confirm command execution still works.

## Command Option Width Validation

1. Open command entry.
2. Trigger command completion for commands with short labels.
3. Verify the option list aligns with the floating input.
4. Verify the option list uses at least 90% of the intended input width.
5. Repeat at terminal widths near 80, 120, and 160 columns.

Expected result: the menu must not look like a narrow detached list under a wider input.

## Notification Validation

Trigger one informational notification:

```vim
:lua require('notifications').notify('UI validation info', 'info', { title = 'Validation' })
```

Trigger one warning notification:

```vim
:lua require('notifications').notify('UI validation warning', 'warn', { title = 'Validation' })
```

Trigger one error notification:

```vim
:lua require('notifications').notify('UI validation error', 'error', { title = 'Validation' })
```

Expected result: notifications appear outside the bottom command-line area, are not duplicated, and warnings/errors remain noticeable.

## Notification History Validation

1. Trigger at least 3 notifications.
2. Open the configured notification history action.
3. Confirm recent notification events are visible with severity/source/message detail.

Expected result: history remains discoverable after provider changes.

## LSP Progress Validation

1. Open a file type with a configured LSP server.
2. Restart or attach the LSP server.
3. Observe startup/progress feedback.

Expected result: progress appears within 1 second, is unobtrusive, and clears within 5 seconds after completion.

## Repeated Startup Validation

Open and close Neovim 5 times with the repository config.

Expected result: no duplicate handlers, duplicate notifications, repeated startup noise, or stale UI artifacts.

## Rollback Validation

If the provider decision must be reverted:

1. Disable or remove the added command-line/message provider configuration.
2. Restore prior Snacks/custom notification behavior.
3. Re-run the static validation commands.
4. Confirm notification history and existing insert-mode completion still work.
