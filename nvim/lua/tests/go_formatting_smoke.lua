-- Public plugin configuration smoke test; no plugins, installs, or disk state.
-- Run: nvim --headless -u NONE -i NONE -l nvim/lua/tests/go_formatting_smoke.lua
vim.opt.runtimepath:prepend(vim.fn.getcwd() .. '/nvim')

local specs = {}
package.loaded['vim-pack'] = {
    add = function(plugins)
        for _, plugin in ipairs(plugins) do
            specs[plugin.src] = plugin
        end
    end,
}

dofile 'nvim/plugin/conform.lua'
vim.api.nvim_exec_autocmds('VimEnter', {})
dofile 'nvim/plugin/mason.lua'

local opts = assert(specs['stevearc/conform.nvim']).opts
assert(
    vim.deep_equal(opts.formatters_by_ft.go, {
        'goimports',
        'golines',
        timeout_ms = 500,
        lsp_format = 'fallback',
    }),
    'Go must run goimports then golines, without LSP preference or stop_after_first'
)
assert(
    vim.deep_equal(opts.formatters.golines, {
        prepend_args = { '--max-len', '80' },
    }),
    'golines must target 80 columns'
)

for _, ft in ipairs { 'c', 'rust' } do
    assert(
        vim.deep_equal(opts.formatters_by_ft[ft], {
            timeout_ms = 500,
            lsp_format = 'prefer',
        }),
        ft .. ' formatting must remain unchanged'
    )
end
assert(opts.formatters_by_ft.markdown == require('config.formatter_chains').markdown)
assert(vim.deep_equal(opts.formatters_by_ft['_'], { 'trim_whitespace', 'trim_newlines' }))
assert(opts.notify_no_formatters == false)

local buf = vim.api.nvim_get_current_buf()
vim.bo[buf].filetype = 'go'
assert(vim.deep_equal(opts.format_on_save(buf), {}))
vim.g.minifiles_active = true
assert(opts.format_on_save(buf) == nil)
vim.g.minifiles_active = false
vim.g.skip_formatting = true
assert(opts.format_on_save(buf) == nil and vim.g.skip_formatting == false)
vim.g.autoformat = false
assert(opts.format_on_save(buf) == nil)
vim.g.autoformat = true
vim.bo[buf].filetype = 'java'
assert(opts.format_on_save(buf) == nil)

local expected = {
    'bash-language-server',
    'css-lsp',
    'dockerfile-language-server',
    'dprint',
    'eslint-lsp',
    'goimports',
    'golines',
    'gopls',
    'html-lsp',
    'json-lsp',
    'lua-language-server',
    'marksman',
    'prettier',
    'ruff',
    'sqls',
    'stylelint-lsp',
    'terraform-ls',
    'yaml-language-server',
}
local requested, installed, refreshed = {}, {}, 0
package.loaded['mason-registry'] = {
    refresh = function(callback)
        refreshed = refreshed + 1
        callback()
    end,
    get_package = function(name)
        requested[#requested + 1] = name
        return {
            is_installed = function()
                return name == 'gopls'
            end,
            install = function()
                installed[#installed + 1] = name
            end,
        }
    end,
}
local mason = assert(specs['mason-org/mason.nvim'])
assert(mason.opts.PATH == 'prepend')
-- Headless startup must still avoid registry refresh and installation.
mason.on_setup()
assert(refreshed == 0 and #requested == 0 and #installed == 0)
local original_uis = vim.api.nvim_list_uis
vim.api.nvim_list_uis = function()
    return { {} }
end
mason.on_setup()
vim.api.nvim_list_uis = original_uis
table.sort(requested)
table.sort(expected)
assert(
    refreshed == 1 and vim.deep_equal(requested, expected),
    'Mason must preserve its existing list and add only the two formatters'
)
local missing = vim.tbl_filter(function(name)
    return name ~= 'gopls'
end, expected)
table.sort(installed)
assert(vim.deep_equal(installed, missing), 'Mason must install missing tools and preserve installed gopls')
print 'PASS Go chain, 80 columns, Mason tools, existing formatting and save guards'
