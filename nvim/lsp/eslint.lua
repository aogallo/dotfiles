-- Install with: pnpm add -g vscode-langservers-extracted

---@type vim.lsp.Config
return {
    cmd = { 'vscode-eslint-language-server', '--stdio' },
    filetypes = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact', 'astro', 'graphql' },
    root_markers = { '.eslintrc', '.eslintrc.js', '.eslintrcjson', 'eslint.config.js', 'eslint.config.mjs' },
    workspace_required = true,
    settings = {
        validate = 'on',
        packageManager = vim.NIL,
        useESLintClass = false,
        experimental = { useFlatConfig = false },
        codeActionOnSave = { enable = false, mode = 'all' },
        format = false,
        quiet = false,
        onIgnoredFiles = 'off',
        options = {},
        rulesCustomizations = {},
        run = 'onType',
        problems = { shortenToSingleLine = false },
        nodePath = '',
        workingDirectory = { mode = 'location' },
        codeAction = {
            disableRuleComment = { enable = true, location = 'separateLine' },
            showDocumentation = { enable = true },
        },
    },
    before_init = function(_, config)
        local root_dir = config.root_dir
        if root_dir then
            config.settings = config.settings or {}
            config.settings.workspaceFolder = {
                uri = root_dir,
                name = vim.fn.fnamemodify(root_dir, ':t'),
            }
        end
    end,
    ---@type table<string, lsp.Handler>
    handlers = {
        ['eslint/openDoc'] = function(_, params)
            vim.ui.open(params.url)
            return {}
        end,
        ['eslint/probeFailed'] = function()
            require('notifications').notify('Probe failed.', 'warn', { title = 'LSP', source = 'eslint' })
            return {}
        end,
        ['eslint/noLibrary'] = function()
            require('notifications').notify(
                'Unable to load ESLint library.',
                'warn',
                { title = 'LSP', source = 'eslint' }
            )
            return {}
        end,
    },
}
