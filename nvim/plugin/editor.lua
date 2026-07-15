local add_on_event = require('vim-pack').add_on_event
local add = require('vim-pack').add

add {
    {
        src = 'folke/snacks.nvim',
        opts = { explorer = { enabled = true }, lazygit = { enabled = true } },
        on_setup = function()
            vim.keymap.set('n', '<leader>e', Snacks.explorer.open, { desc = 'Explorer', silent = true })
            vim.keymap.set('n', '<leader>bo', Snacks.bufdelete.other, { desc = 'Delete other buffers', silent = true })
            vim.keymap.set('n', '<leader>gg', Snacks.lazygit.open, { desc = 'Lazygit', silent = true })
        end,
    },
    {
        src = 'nvim-tree/nvim-web-devicons',
        opts = {
            -- Make the icon for query files more visible.
            override = {
                scm = {
                    icon = '󰘧',
                    color = '#A9ABAC',
                    cterm_color = '16',
                    name = 'Scheme',
                },
            },
        },
    },
    { src = 'folke/tokyonight.nvim', opts = { style = 'moon' } },
    {
        src = 'folke/which-key.nvim',
        on_setup = function()
            local wk = require 'which-key'
            wk.add {
                { '<leader>b', group = 'buffers' },
                { '<leader>c', group = 'code' },
                { '<leader>f', group = 'file' },
                { '<leader>g', group = 'git' },
                { '<leader>p', group = 'pack manager' },
            }
        end,
    },

    {
        src = 'christoomey/vim-tmux-navigator',
        setup = false,
    },
}

-- Whitespace and indentation guides.
add_on_event('UIEnter', {
    {
        src = 'lukas-reineke/indent-blankline.nvim',
        module_name = 'ibl',
        opts = {
            indent = {
                char = require('icons').misc.vertical_bar,
            },
            scope = {
                show_start = false,
                show_end = false,
            },
        },
    },
})

vim.cmd [[colorscheme tokyonight]]
