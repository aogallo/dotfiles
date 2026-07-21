local add = require('vim-pack').add

local markdown_project_markers = {
    '.prettierrc',
    '.prettierrc.cjs',
    '.prettierrc.js',
    '.prettierrc.json',
    '.prettierrc.json5',
    '.prettierrc.mjs',
    '.prettierrc.toml',
    '.prettierrc.yaml',
    '.prettierrc.yml',
    'package.json',
    'prettier.config.cjs',
    'prettier.config.js',
    'prettier.config.mjs',
    'prettier.config.ts',
}

local function has_markdown_project_signal(bufnr)
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    local start = bufname ~= '' and vim.fs.dirname(bufname) or vim.fn.getcwd()

    if not start or start == '' then
        return false
    end

    return #vim.fs.find(markdown_project_markers, { path = start, upward = true, type = 'file' }) > 0
end

local function markdown_formatters(bufnr)
    if has_markdown_project_signal(bufnr) then
        return { 'prettier', timeout_ms = 500, lsp_format = 'fallback' }
    end

    return { 'markdown_prettier', 'trim_whitespace', 'trim_newlines', timeout_ms = 500, stop_after_first = true }
end

local conform_loaded = false
local conform_plugins = {
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
                markdown = markdown_formatters,
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
                markdown_prettier = { inherit = 'prettier', require_cwd = false },
                prettier = { require_cwd = true },
            },
        },
    },
}

vim.api.nvim_create_autocmd({ 'BufReadPre', 'BufNewFile', 'VimEnter', 'BufWritePre' }, {
    callback = function()
        if conform_loaded then
            return
        end

        conform_loaded = true
        add(conform_plugins)
    end,
})

vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"

vim.g.autoformat = true
