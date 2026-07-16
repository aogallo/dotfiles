# Quickstart: Validate Neovim Notifications

## Prerequisites

- Open this repository's Neovim configuration.
- Ensure packages are installed or synced through the existing package workflow.
- Confirm `folke/snacks.nvim` is available in the Neovim session.

## Scenario 1: Visible Notification

1. Start Neovim with this configuration.
2. Trigger an informational notification from the command line: `:lua vim.notify("Hello from Neovim", vim.log.levels.INFO, { title = "Notify smoke" })`.
3. Trigger warning and error notifications: `:lua vim.notify("Warning smoke", vim.log.levels.WARN, { title = "Notify smoke" })` and `:lua vim.notify("Error smoke", vim.log.levels.ERROR, { title = "Notify smoke" })`.
4. Expected: each message appears in a visible notification surface outside the command line and editing focus remains intact.

## Scenario 2: Notification History

1. Trigger at least three notifications with different severities.
2. Open notification history with `<leader>un`.
3. Expected: recent notifications are readable, ordered, and easier to scan than raw command messages.
4. Expected: each history entry shows message text, severity, source/title when available, and clear ordering.
5. In a fresh Neovim session with no manual notifications, open `<leader>un`.
6. Expected: the history view opens without errors and does not require reading raw `:messages` output.
7. Trigger a long notification: `:lua vim.notify(string.rep("Long history smoke ", 20), vim.log.levels.WARN, { title = "Notify smoke" })`.
8. Expected: history remains readable and focused on notification entries rather than unrelated command-line noise.

## Scenario 3: Burst Handling

1. Trigger 10 notifications quickly in the same session.
2. Continue typing or moving in a buffer.
3. Expected: editing remains responsive and the notifications do not permanently obscure the editor.

## Scenario 4: LSP Progress Readiness

1. Open a project that starts a configured language server.
2. Expected: when a language server attaches, one `<server> is attached` notification appears for that server/buffer pair.
3. Watch for startup or progress feedback.
4. Expected: progress start and completion or failure feedback uses the same notification experience and can be reviewed in history.
5. If a real language server does not emit visible progress during validation, trigger a synthetic progress event from a running LSP client with `:lua vim.api.nvim_exec_autocmds("LspProgress", { data = { client_id = vim.lsp.get_clients()[1].id, params = { token = "notify-smoke", value = { kind = "begin", title = "Indexing", message = "notify smoke", percentage = 10 } } } })`.
6. Trigger completion for the same token with `:lua vim.api.nvim_exec_autocmds("LspProgress", { data = { client_id = vim.lsp.get_clients()[1].id, params = { token = "notify-smoke", value = { kind = "end", title = "Indexing", message = "done" } } } })`.
7. Expected: both progress states update one LSP progress notification and remain reviewable in notification history.
8. If a language server exits unexpectedly, expected failure copy is `<server> failed: <reason>` with title `LSP`, severity error, and a history entry.

## Scenario 5: Repeated Startup Safety

1. Start Neovim, trigger one notification, and confirm one visible message appears.
2. Restart Neovim and repeat the same notification trigger.
3. Expected: a single event creates one visible notification, not duplicates from repeated handler registration.

## Troubleshooting Checks

- If notifications still appear only in the command line, verify that Snacks loaded and the notifier capability is enabled.
- If history does not open, verify the history action calls the Snacks notifier history entry point.
- If LSP progress floods the UI, verify progress updates reuse a stable progress identity.
- If a removed plugin reappears, verify it is not present in `nvim/nvim-pack-lock.json` and remove stale plugin directories from Neovim's package path.
- Plugin disk cleanup should be tracked by issue #27 before adding a reusable command or workflow.
