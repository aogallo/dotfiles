# Quickstart: Unify Neovim Notifications

## Prerequisites

- Run from the repository root.
- Neovim dependencies should be available as documented in `nvim/README.md` and `nvim/dependencies.tsv`.
- For LSP progress validation, use a project that starts a configured language server such as `tsgo` or `lua_ls`.

## Static Validation

1. Format check:

   ```sh
   stylua --check nvim
   ```

2. Startup smoke test:

   ```sh
   nvim --headless -u nvim/init.lua '+quitall'
   ```

3. Health checks:

   ```sh
   nvim --headless -u nvim/init.lua '+checkhealth vim.lsp' '+checkhealth nvim-treesitter' '+checkhealth mason' '+quitall'
   ```

4. Dependency validation:

   ```sh
   setup/validate-nvim-deps.sh
   ```

## Manual Validation Scenarios

### Scenario 1: Basic Notification Severities

1. Open Neovim with this config.
2. Trigger one info, warning, and error notification.
3. Confirm each appears in the same LazyVim-like popup format with distinct severity styling.
4. Confirm focus remains in the editing window.

**Expected**: All severities use one visual language and are later visible in history.

### Scenario 2: Notification/Message History

1. Produce several notifications and editor messages.
2. Open notification/message history through the configured UI mapping or command.
3. Search for a recent message.
4. Select it and inspect the detail preview.

**Expected**: The history is picker-style, searchable, and shows detail preview in under 10 seconds.

### Scenario 3: Command Failure

1. Open a file with changes.
2. Trigger the previously reported `<leader>gd`/Diffview-style action or an equivalent command failure.
3. Observe the notification surface and history.

**Expected**: The failure is not only raw command-line output. A visible error notification summarizes the failed action, and full details remain reviewable.

### Scenario 4: LSP Progress and Attach

1. Open a project that starts a configured language server, preferably `tsgo` for TypeScript or `lua_ls` for Lua.
2. Observe LSP attach/progress notifications.
3. Wait for progress completion or trigger a failure scenario if practical.

**Expected**: LSP feedback uses the same LazyVim-like notification language, shows the client/source, updates without noisy duplicates, and remains reviewable.

### Scenario 5: Mixed Burst

1. Trigger 10 mixed notification/message events close together.
2. Continue typing or moving in the editor.
3. Open history afterward.

**Expected**: Editing remains usable, important messages remain readable, and all recent events are available in history.

### Scenario 6: Diagnostics No-Regression

1. Open a file with known diagnostics.
2. Compare inline/current-line diagnostics behavior with the pre-feature baseline.
3. Trigger notifications while diagnostics are visible.

**Expected**: Diagnostics presentation is not redesigned by this feature and does not regress due to notification/message changes.

### Scenario 7: Repeated Load/Idempotency

1. Restart Neovim or source the relevant config repeatedly during development.
2. Trigger a representative notification and LSP progress event.

**Expected**: No duplicate handlers or duplicate visible notifications are created.

## Rollback

Rollback is a normal repository revert of the Neovim configuration changes. No persisted notification/message data or user-owned files are modified by this feature.

## Implementation Validation Notes

- `stylua --check nvim`: passed during `/speckit.implement` execution.
- `nvim --headless -u nvim/init.lua '+quitall'`: passed during `/speckit.implement` execution.
- `nvim --headless -u nvim/init.lua '+checkhealth vim.lsp' '+checkhealth nvim-treesitter' '+checkhealth mason' '+quitall'`: passed during `/speckit.implement` execution.
- `setup/validate-nvim-deps.sh`: passed for required dependencies during `/speckit.implement` execution; optional `shfmt` and `shellcheck` were reported missing.
- Manual interactive scenarios 1-7 require an attached Neovim UI and a project with active LSP clients; they were validated during attached-UI review after the headless implementation run.
- Notification history is mapped to `<leader>un`. When Snacks native notifier history has entries, it opens `Snacks.notifier.show_history()`. If native history is empty but the helper has internal captured entries, it falls back to the custom Snacks picker (`Snacks.picker.pick`), then `Snacks.picker.notifications()`, then quickfix-backed session history.
- Command/keymap failures routed through the unified helper show concise visible summaries while the helper retains full details for review/fallback history.
- `<leader>gd` runs `DiffviewOpen` through the unified action wrapper, so Diffview command failures include the `Diff view` action context in the visible error summary and retained details.
- Focused headless smoke validated that `notifications.command_failure()` records history and that `<leader>gd` is installed as a wrapped Lua callback. Attached UI validation later confirmed the command-failure wrapper path shows contextual errors and preserves details in history.
- Attached UI validation confirmed direct `vim.notify()` info and warning notifications render successfully after restarting Neovim, including the persistent Snacks notify wrapper fix.
- Attached UI validation confirmed `<leader>un` opens notification history without errors and shows the direct info/warning notifications with correct severity context.
- Attached UI validation confirmed LSP attach/progress notifications use the unified notification style, avoid noisy duplicate attach messages, and appear in notification history.
- Attached UI validation confirmed a burst of 10 mixed info/warning notifications does not crash, remains usable, and keeps recent events available through history.
- Attached UI validation confirmed diagnostics presentation does not regress or break while notifications are active.
- Attached UI validation confirmed repeated `:source $MYVIMRC` reloads do not create duplicate notifications, do not reintroduce notification lifecycle errors, and keep `<leader>un` usable.
- Attached UI validation confirmed the command-failure wrapper path with `notifications.wrap_action()` shows a contextual error notification and keeps details available in history.
