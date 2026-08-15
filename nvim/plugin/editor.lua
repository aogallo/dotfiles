local add_on_event = require('vim-pack').add_on_event
local add = require('vim-pack').add
local notification_icons = require('icons').notifications
local notifications = require 'notifications'

add {
    {
        src = 'folke/snacks.nvim',
        opts = {
            dashboard = {
                enabled = true,
                sections = {
                    { section = 'header' },
                    { icon = ' ', title = 'Keymaps', section = 'keys', gap = 1, padding = 1, indent = 2 },
                    { icon = '󰈙 ', title = 'Recent Files', section = 'recent_files', indent = 2, padding = 2 },
                },
            },
            input = { enabled = true },
            explorer = { enabled = true },
            lazygit = { enabled = true },
            picker = { enabled = true },
            notifier = {
                enabled = true,
                timeout = 3000,
                width = { min = 40, max = 0.4 },
                height = { min = 1, max = 0.6 },
                margin = { top = 0, right = 1, bottom = 0 },
                padding = true,
                level = vim.log.levels.TRACE,
                icons = {
                    error = notification_icons.error .. ' ',
                    warn = notification_icons.warn .. ' ',
                    info = notification_icons.info .. ' ',
                    debug = notification_icons.debug .. ' ',
                    trace = notification_icons.trace .. ' ',
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
            local titles = {
                trace = 'Trace',
                debug = 'Debug',
                info = 'Info',
                progress = 'Progress',
                warn = 'Warning',
                error = 'Error',
            }

            local function install_notify_wrapper()
                _G.__aogallo_notify = _G.__aogallo_notify or {}
                local state = _G.__aogallo_notify

                if vim.notify == state.wrapped then
                    return
                end

                state.base = vim.notify
                state.wrapped = state.wrapped
                    or function(message, level, opts)
                        opts = vim.tbl_deep_extend('force', {}, opts or {})

                        local severity = select(1, notifications.normalize_severity(level or opts.level))
                        opts.title = opts.title or titles[severity]
                        opts.icon = opts.icon or (notification_icons[severity] or notification_icons.info) .. ' '

                        local result = state.base(message, level, opts)
                        if vim.notify ~= state.wrapped then
                            state.base = vim.notify
                            vim.notify = state.wrapped
                        end
                        return result
                    end

                vim.notify = state.wrapped
            end

            install_notify_wrapper()
            vim.schedule(install_notify_wrapper)

            if not Snacks.notifier then
                notifications.notify(
                    'Snacks notifier is unavailable; using the default notification handler.',
                    'warn',
                    { title = 'Notifications' }
                )
            end

            vim.keymap.set('n', '<leader>un', notifications.open_history, {
                desc = 'Notification history',
                silent = true,
            })

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
                { '<leader>n', group = 'notes' },
                { '<leader>p', group = 'packages' },
                { '<leader>s', group = 'search' },
                { '<leader>u', group = 'ui' },
                { '<leader>w', group = 'windows' },
                { '<S-h>', desc = 'Next buffer', hidden = true },
                { '<S-l>', desc = 'Previous buffer', hidden = true },
            }
        end,
    },

    {
        src = 'nvim-lualine/lualine.nvim',
        opts = {
            options = {
                globalstatus = true,
                theme = 'auto',
                component_separators = { left = '', right = '' },
                section_separators = { left = '', right = '' },
                disabled_filetypes = { statusline = { 'dashboard' } },
            },
            sections = {
                lualine_a = { 'mode' },
                lualine_b = { 'branch' },
                lualine_c = { { 'filename', file_status = true, path = 1 } },
                lualine_x = {
                    { 'diagnostics', sources = { 'nvim_diagnostic' } },
                    'encoding',
                    'filetype',
                },
                lualine_y = {},
                lualine_z = { 'location' },
            },
            inactive_sections = {
                lualine_a = {},
                lualine_b = {},
                lualine_c = { { 'filename', file_status = true, path = 1 } },
                lualine_x = { 'location' },
                lualine_y = {},
                lualine_z = {},
            },
        },
    },
    {
        src = 'akinsho/bufferline.nvim',
        opts = {
            options = {
                mode = 'buffers',
                diagnostics = 'nvim_lsp',
                diagnostics_update_on_event = true,
                show_buffer_close_icons = true,
                show_close_icon = true,
                modified_icon = '●',
                auto_toggle_bufferline = true,
                separator_style = 'slant',
            },
        },
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
