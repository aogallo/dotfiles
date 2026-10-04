local add_on_event = require('vim-pack').add_on_event
local add = require('vim-pack').add

-- Database context in the status line (spec 009, US4): the database a SQL
-- buffer's connection declares, and a warning beside it when the text would
-- switch to another one. Renders nothing for any other filetype, so the
-- component costs nothing outside SQL. The text comes from
-- config/db_context.lua, which never puts a URL, host, or password in it; the
-- read is on the current buffer only, so it needs no server round-trip.
local function db_context_component()
    local db_context = require 'config.db_context'
    local buf = vim.api.nvim_get_current_buf()
    local text = db_context.label(buf)
    if text == '' then
        return ''
    end
    -- A conflict is a warning about the text, not a broken buffer, so it takes
    -- the warning group rather than the error one.
    return text, db_context.conflict(buf) and 'DiagnosticWarn' or 'Directory'
end

local notification_icons = require('icons').notifications
local notifications = require 'notifications'

-- Buffer-visibility guard (specs/011-query-buffer-tab-visibility, issue #96).
-- Restores the tab of a buffer the developer opened and then closed, so it is
-- not left with a tab-less buffer in front of them. Additive only: it re-lists,
-- it never unlists. Called from here, at plugin source time, because the guard
-- is editor-level — it knows nothing about databases and must be live with no
-- database loaded. The database query draft registry registers itself with it
-- from nvim/plugin/database.lua; nothing below changes bufferline's options.
require('config.buffers').setup()

-- Single source of truth for the highlight groups this repository overrides.
--
-- Load order is what makes this work, and it is why the colorscheme is applied
-- above in its own batch. bufferline derives its palette from the highlight
-- groups present when it is set up, and it used to be set up before any
-- colorscheme existed -- so it fell back to Neovim's built-in defaults (#101).
--
-- Applying the colorscheme first is sufficient: bufferline applies its derived
-- highlights with nvim_set_hl(..., { default = true }) because config.options
-- .themable defaults to true and this configuration does not disable it, so it
-- leaves alone any group that is already defined. The overrides below win by
-- being defined first. Setting themable = false would break that and would then
-- need an explicit re-apply after bufferline's setup.
--
-- Every colour is a tokyonight palette token rather than a hand-picked literal,
-- so switching tokyonight's style carries them instead of leaving them stranded.
--
-- Under any other colorscheme this function does not run at all, bufferline
-- derives the row natively from that colorscheme, and none of these values leak
-- into it.
local palette

local function apply_editor_highlights(hl, c)
    c = c or palette
    palette = c
    if not c then
        return
    end

    -- Keep low-priority text readable without flattening Tokyonight moon.
    local readable_comment = '#9aa7cf'
    local hidden_path = '#a9b8e8'
    local explorer_row = '#2d3f76'

    -- Background of the buffer tab being edited. Taken from the palette's own
    -- bg_highlight, and deliberately not the same value as explorer_row: that one
    -- drives SnacksPickerListCursorLine, and sharing a literal made the active tab
    -- and the picker row read as one layer. specs/012's highlight-contract.md is
    -- the authority for every value below.
    local active_tab_bg = c.bg_highlight

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

    -- Relative line numbers. Tokyonight's gutter grey measured 1.56:1 against
    -- Normal, below the 3.0 floor; dark5 clears it at 3.67:1 while staying a
    -- desaturated grey-blue rather than a vivid accent. The cursor's own number
    -- keeps c.orange at 7.16:1 in its own column, so the ordinal order is
    -- preserved rather than flattened.
    hl.LineNr = { fg = c.dark5 }
    hl.LineNrAbove = { fg = c.dark5 }
    hl.LineNrBelow = { fg = c.dark5 }

    -- Buffer row. The active tab carries the emphasis through two channels: the
    -- strongest name and a background the inactive row no longer shares.
    hl.BufferLineBufferSelected = { fg = c.fg, bg = active_tab_bg, bold = true }
    hl.BufferLineBufferVisible = { fg = c.fg_dark, bg = c.bg_dark1 }
    hl.BufferLineBuffer = { fg = c.comment, bg = c.bg_dark1 }
    hl.BufferLineIndicatorSelected = { fg = c.blue }
    -- fg equals bg so the separator divides segments without drawing an edge
    -- inside the tab that should read as one solid block.
    hl.BufferLineSeparatorSelected = { fg = active_tab_bg, bg = active_tab_bg }

    -- Overlays on the active tab. Bold marks a diagnostic severity, so only the
    -- four severities carry it; Modified and CloseButton are state markers.
    hl.BufferLineErrorSelected = { fg = c.red, bg = active_tab_bg, bold = true }
    hl.BufferLineWarningSelected = { fg = c.orange, bg = active_tab_bg, bold = true }
    hl.BufferLineInfoSelected = { fg = c.blue2, bg = active_tab_bg, bold = true }
    hl.BufferLineHintSelected = { fg = c.blue5, bg = active_tab_bg, bold = true }
    hl.BufferLineModifiedSelected = { fg = c.green, bg = active_tab_bg }
    hl.BufferLineCloseButtonSelected = { fg = c.fg, bg = active_tab_bg }
end

-- The colorscheme is applied between the two batches on purpose. Anything that
-- derives its palette from the highlight groups has to see tokyonight first.
add {
    {
        src = 'folke/tokyonight.nvim',
        opts = {
            style = 'moon',
            on_highlights = apply_editor_highlights,
        },
    },
}

vim.cmd [[colorscheme tokyonight]]

add {
    { src = 'nvim-lua/plenary.nvim' },
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
            explorer = { enabled = true, include = { '.env', '.env.*' } },
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
                { '<leader>q', group = 'database' },
                { '<leader>s', group = 'search' },
                { '<leader>u', group = 'ui' },
                { '<leader>w', group = 'windows' },
                { '<S-h>', desc = 'Next buffer', hidden = true },
                { '<S-l>', desc = 'Previous buffer', hidden = true },
            }
        end,
    },

    -- Status line (spec 008, US3): one neutral section for mode, branch, file,
    -- diagnostics, encoding, filetype, location; the editor's own sections stay
    -- empty so a plugin adding one is visible rather than doubled.
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
                lualine_y = { db_context_component },
                lualine_z = { 'location' },
            },
            inactive_sections = {
                lualine_a = {},
                lualine_b = {},
                lualine_c = { { 'filename', file_status = true, path = 1 } },
                lualine_x = { 'location' },
                lualine_y = { db_context_component },
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
    {
        -- Highlights TODO/FIXME/HACK in code and markdown. The empty opts are
        -- intentional: the defaults are what the editor wants, and every setting
        -- here would be a knob nobody has asked for.
        src = 'folke/todo-comments.nvim',
        opts = {},
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
