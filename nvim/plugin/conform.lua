local add = require('vim-pack').add

local chains = require 'config.formatter_chains'

local conform_loaded = false

-- save_will_format(bufnr, consume): is this save going to be formatted?
-- Called by: format_on_save below, and by the BufWritePre availability check
--   that warns when a save had no formatter at all (FR-008)
-- Args: bufnr = buffer being written; consume = true only for the caller that
--   owns the one-shot vim.g.skip_formatting flag
-- Returns: boolean
-- Side effects: clears vim.g.skip_formatting when consume is true
--
-- One copy of these guards on purpose. The warning below must not be able to
-- report a failure for a save that was never going to be formatted
-- (contracts/whitespace-fallback.md §4 rule 3), and the only reliable way to
-- guarantee that is to ask the same function the formatter asks.
local function save_will_format(bufnr, consume)
    if vim.bo[bufnr].filetype == 'java' then
        -- Java formatting is too slow to do on save.
        return false
    end

    -- Don't format when minifiles is open, since that triggers the "confirm without
    -- synchronization" message.
    if vim.g.minifiles_active then
        return false
    end

    -- Skip formatting if triggered from my special save command. The flag is
    -- one-shot, so only the caller that acts on it may clear it; the warning
    -- reads it and leaves it for format_on_save.
    if vim.g.skip_formatting then
        if consume then
            vim.g.skip_formatting = false
        end
        return false
    end

    -- Stop if we disabled auto-formatting.
    return vim.g.autoformat and true or false
end

-- A save that finds no formatter used to stay silent after the first one: the
-- toolchain's own notice is a per-filetype, per-session flag, so a file that
-- kept failing to be cleaned went quiet. That notice is turned off below and
-- replaced by this check, which warns on every failing save. It only reads
-- state and never touches the buffer, so it cannot race the formatter
-- (contracts/whitespace-fallback.md §3, §4 rule 2).
local warning_group = vim.api.nvim_create_augroup('ConformNoFormatterWarning', { clear = true })
vim.api.nvim_create_autocmd('BufWritePre', {
    group = warning_group,
    desc = 'Warn when a save had no formatter for this file type (FR-008)',
    callback = function(args)
        local bufnr = args.buf
        if vim.bo[bufnr].buftype ~= '' then
            return
        end
        if not save_will_format(bufnr, false) then
            return
        end
        local ok, conform = pcall(require, 'conform')
        if not ok then
            return
        end
        local message = chains.no_formatter_message(vim.bo[bufnr].filetype)
        if not message or #conform.list_formatters_to_run(bufnr) > 0 then
            return
        end
        require('notifications').notify(message, vim.log.levels.WARN, { source = 'conform' })
    end,
})
local conform_plugins = {
    {
        src = 'stevearc/conform.nvim',
        opts = {

            notify_on_error = true,
            -- Replaced by the BufWritePre check above, which warns on every
            -- failing save instead of only the first one per session.
            notify_no_formatters = false,
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
                markdown = chains.markdown,
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
            -- format_on_save(bufnr): run the configured chain for this buffer.
            -- Called by: conform.nvim, once per save, and nothing else
            -- SQL: none
            -- Args: bufnr = buffer being written (conform passes exactly one)
            -- Returns: nil when a guard in save_will_format() declines the
            --   save, otherwise an empty options table, which asks conform to
            --   format with the chain this file's filetype resolves to
            -- Side effects: formats the buffer, and consumes the one-shot
            --   vim.g.skip_formatting flag through save_will_format()
            format_on_save = function(bufnr)
                if not save_will_format(bufnr, true) then
                    return nil
                end

                return {}
            end,
            formatters = {
                markdown_prettier = { inherit = 'prettier', require_cwd = false },
                prettier = { require_cwd = false },
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
