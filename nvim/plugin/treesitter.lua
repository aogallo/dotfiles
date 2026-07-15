local add = require('vim-pack').add
local on_plugin_update = require('vim-pack').on_plugin_update

local parses = {
    'bash',
    'c',
    'cpp',
    'dart',
    'dockerfile',
    'dot',
    'fish',
    'gitcommit',
    'go',
    'graphql',
    'html',
    'hyprlang',
    'java',
    'javascript',
    'json',
    'json5',
    'lua',
    'markdown',
    'markdown_inline',
    'python',
    'query',
    'rasi',
    'regex',
    'rust',
    'scss',
    'toml',
    'tsx',
    'typescript',
    'vim',
    'vimdoc',
    'yaml',
    'terraform',
    'hcl',
}

local function add_treesitter_runtimepath()
    -- Main-branch nvim-treesitter ships queries under `runtime/`, which isn't
    -- on rtp by default. Prepend it so highlights/folds/indents are visible to
    -- `vim.treesitter.start`.
    local init = vim.api.nvim_get_runtime_file('lua/nvim-treesitter/init.lua', false)[1]
    if init then
        vim.opt.runtimepath:prepend(vim.fn.fnamemodify(init, ':h:h:h') .. '/runtime')
    end
end

local function install_parsers()
    require('nvim-treesitter').install(parses):wait(300000)
end

local function update_parsers()
    install_parsers()
    require('nvim-treesitter').update():wait(300000)
end

-- Highlight, edit, and navigate code.
add {
    {
        src = 'nvim-treesitter/nvim-treesitter',
        on_setup = function()
            add_treesitter_runtimepath()

            vim.api.nvim_create_user_command('TSInstallConfigured', install_parsers, {
                desc = 'Install configured Treesitter parsers',
            })
            vim.api.nvim_create_user_command('TSUpdateConfigured', update_parsers, {
                desc = 'Update configured Treesitter parsers',
            })
        end,
    },
    {
        src = 'nvim-treesitter/nvim-treesitter-context',
        module_name = 'treesitter-context',
        opts = {
            max_lines = 3,
            multiline_threshold = 1,
            min_window_height = 20,
        },
        on_setup = function()
            vim.keymap.set('n', '[c', function()
                if vim.wo.diff then
                    return '[c'
                else
                    vim.schedule(function()
                        require('treesitter-context').go_to_context()
                    end)
                    return '<Ignore>'
                end
            end, { desc = 'Jump to upper context', expr = true })
        end,
    },
}

on_plugin_update('nvim-treesitter', function()
    update_parsers()
end)
