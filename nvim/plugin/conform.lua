local add_on_event = require('vim-pack').add_on_event

add_on_event('BufWritePre', {
    {
        src = 'stevearc/conform.nvim',
        opts = {

            notify_on_error = true,
            notify_no_formatters = true,
            formatters_by_ft = {
                c = { timeout_ms = 500, lsp_format = 'prefer' },
                go = { timeout_ms = 500, lsp_format = 'prefer' },
                java = { 'palantir-java-format' },
                javascript = {
                    'prettier',
                    'dprint',
                    timeout_ms = 500,
                    lsp_format = 'fallback',
                    stop_after_first = true,
                },
                javascriptreact = {
                    'prettier',
                    'dprint',
                    timeout_ms = 500,
                    lsp_format = 'fallback',
                    stop_after_first = true,
                },
                json = { 'prettier', 'dprint', timeout_ms = 500, lsp_format = 'fallback', stop_after_first = true },
                jsonc = { 'prettier', 'dprint', timeout_ms = 500, lsp_format = 'fallback', stop_after_first = true },
                less = { 'prettier' },
                lua = { 'stylua' },
                markdown = { 'prettier', timeout_ms = 500, lsp_format = 'fallback' },
                python = { 'ruff_format' },
                rust = { timeout_ms = 500, lsp_format = 'prefer' },
                scss = { 'prettier' },
                sh = { 'shfmt' },
                typescript = {
                    'prettier',
                    'dprint',
                    timeout_ms = 500,
                    lsp_format = 'fallback',
                    stop_after_first = true,
                },
                typescriptreact = {
                    'prettier',
                    'dprint',
                    timeout_ms = 500,
                    lsp_format = 'fallback',
                    stop_after_first = true,
                },
                yaml = { 'prettier' },
                -- For filetypes without a formatter:
                ['_'] = { 'trim_whitespace', 'trim_newlines' },
                hcl = { 'packer_fmt' },
                terraform = { 'terraform_fmt' },
                tf = { 'terraform_fmt' },
                ['terraform-vars'] = { 'terraform_fmt' },
            },
            format_on_save = function()
                if vim.bo.filetype == 'java' then
                    -- Java formatting is too slow to do on save.
                    return nil
                end

                -- Don't format when minifiles is open, since that triggers the "confirm without
                -- synchronization" message.
                if vim.g.minifiles_active then
                    return nil
                end

                -- Skip formatting if triggered from my special save command.
                if vim.g.skip_formatting then
                    vim.g.skip_formatting = false
                    return nil
                end

                -- Stop if we disabled auto-formatting.
                if not vim.g.autoformat then
                    return nil
                end

                return {}
            end,
            formatters = {
                prettier = { require_cwd = true },
            },
        },
    },
})

vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"

vim.g.autoformat = true
