local add_on_file_type = require('vim-pack').add_on_file_type
local on_plugin_update = require('vim-pack').on_plugin_update
local add = require('vim-pack').add

local notes_dir = vim.env.OBSIDIAN_NOTES_DIR
if not notes_dir or notes_dir == '' then
    notes_dir = vim.fs.joinpath(vim.env.HOME, 'dev', 'notes')
end

add {
    {
        src = 'obsidian-nvim/obsidian.nvim',
        opts = function()
            return {
                picker = { name = 'snacks.picker' },
                legacy_commands = false,
                note_id_func = require('obsidian.builtin').title_id,
                workspaces = { { name = 'notes', path = notes_dir } },
            }
        end,
        on_setup = function()
            vim.opt.conceallevel = 2

            vim.keymap.set('n', '<leader>nn', ':Obsidian new ', { desc = 'New note' })
        end,
    },
}

-- Markdown preview on the browser.
add_on_file_type('markdown', {
    {
        src = 'MeanderingProgrammer/render-markdown.nvim',
        opts = {
            code = {
                sign = false,
            },
            heading = {
                sign = false,
                position = 'inline',
            },
            html = {
                enabled = true,
                comment = {
                    conceal = false,
                },
            },
        },
    },
    {
        src = 'iamcco/markdown-preview.nvim',
        -- Vimscript-driven plugin: no Lua setup() to call.
        setup = false,
        on_setup = function()
            vim.keymap.set('n', '<leader>up', '<cmd>MarkdownPreviewToggle<cr>', {
                desc = 'Markdown preview',
            })

            vim.fn['mkdp#util#install']()
        end,
    },
})

on_plugin_update('markdown-preview.nvim', function()
    vim.fn['mkdp#util#install_sync'](true)
end)
