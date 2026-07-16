local add_on_event = require('vim-pack').add_on_event
local add = require('vim-pack').add
local diagnostic_icons = require('icons').diagnostics
local misc_icons = require('icons').misc

add {
    {
        src = 'folke/snacks.nvim',
        opts = {
            explorer = { enabled = true },
            lazygit = { enabled = true },
            notifier = {
                enabled = true,
                timeout = 3000,
                width = { min = 40, max = 0.4 },
                height = { min = 1, max = 0.6 },
                margin = { top = 0, right = 1, bottom = 0 },
                padding = true,
                level = vim.log.levels.TRACE,
                icons = {
                    error = diagnostic_icons.ERROR .. ' ',
                    warn = diagnostic_icons.WARN .. ' ',
                    info = diagnostic_icons.INFO .. ' ',
                    debug = misc_icons.bug .. ' ',
                    trace = misc_icons.ellipsis .. ' ',
                },
                keep = function()
                    return vim.fn.getcmdpos() > 0
                end,
                style = 'compact',
                top_down = true,
                date_format = '%R',
            },
        },
        on_setup = function()
            if not Snacks.notifier then
                vim.notify(
                    'Snacks notifier is unavailable; using the default notification handler.',
                    vim.log.levels.WARN
                )
            else
                vim.keymap.set('n', '<leader>un', Snacks.notifier.show_history, {
                    desc = 'Notification history',
                    silent = true,
                })
            end

            vim.keymap.set('n', '<leader>fe', Snacks.explorer.open, { desc = 'Explorer', silent = true })
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
    {
        src = 'folke/tokyonight.nvim',
        opts = {
            style = 'moon',
            on_highlights = function(hl, c)
                -- Keep low-priority text readable without flattening Tokyonight moon.
                local readable_comment = '#9aa7cf'
                local hidden_path = '#a9b8e8'
                local explorer_row = '#2d3f76'

                hl.Comment = { fg = readable_comment, italic = true }
                hl['@comment'] = { fg = readable_comment, italic = true }
                hl.SnacksPickerComment = { fg = readable_comment, italic = true }

                hl.SnacksPickerPathHidden = { fg = hidden_path }
                hl.SnacksPickerPathIgnored = { fg = c.fg_gutter }
                hl.SnacksPickerFile = { fg = c.fg }
                hl.SnacksPickerDirectory = { fg = c.blue, bold = true }
                hl.SnacksPickerDir = { fg = c.fg_gutter }

                hl.SnacksPickerListCursorLine = { bg = explorer_row }
                hl.SnacksPickerSelected = { fg = c.orange, bold = true }
                hl.SnacksPickerGitStatusUntracked = { fg = c.green }
                hl.SnacksPickerGitStatusIgnored = { fg = c.dark5 }
            end,
        },
    },
    {
        src = 'folke/which-key.nvim',
        on_setup = function()
            local wk = require 'which-key'
            wk.add {
                { '<leader>b', group = 'buffers' },
                { '<leader>c', group = 'code' },
                { '<leader>f', group = 'files' },
                { '<leader>g', group = 'git' },
                { '<leader>p', group = 'packages' },
                { '<leader>s', group = 'search' },
                { '<leader>u', group = 'ui' },
                { '<leader>w', group = 'windows' },
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
