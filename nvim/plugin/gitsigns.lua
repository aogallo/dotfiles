local add = require('vim-pack').add
local add_on_event = require('vim-pack').add_on_event

local solid_bar = require('icons').misc.vertical_bar
local dashed_bar = require('icons').misc.dashed_bar

local gitlinker_router = {}
if vim.env.GITLINKER_ENTERPRISE_HOST and vim.env.GITLINKER_ENTERPRISE_HOST ~= '' then
    local host_pattern = '^' .. vim.pesc(vim.env.GITLINKER_ENTERPRISE_HOST)
    gitlinker_router = {
        browse = {
            [host_pattern] = require('gitlinker.routers').github_browse,
        },
        blame = {
            [host_pattern] = require('gitlinker.routers').github_blame,
        },
    }
end

add_on_event({ 'BufReadPre', 'BufNewFile' }, {
    {
        src = 'lewis6991/gitsigns.nvim',
        opts = {
            signs = {
                add = { text = solid_bar },
                untracked = { text = solid_bar },
                change = { text = solid_bar },
                delete = { text = solid_bar },
                topdelete = { text = solid_bar },
                changedelete = { text = solid_bar },
            },
            signs_staged = {
                add = { text = dashed_bar },
                untracked = { text = dashed_bar },
                change = { text = dashed_bar },
                delete = { text = dashed_bar },
                topdelete = { text = dashed_bar },
                changedelete = { text = dashed_bar },
            },
            preview_config = { border = 'rounded' },
            current_line_blame = true,
            gh = true,
            on_attach = function(bufnr)
                local gs = package.loaded.gitsigns
                vim.b[bufnr].miniclue_config = {
                    clues = {
                        { mode = 'n', keys = '<leader>g', desc = '+git' },
                        { mode = 'x', keys = '<leader>g', desc = '+git' },
                    },
                }

                -- Mappings.
                ---@param lhs string
                ---@param rhs function
                ---@param desc string
                local function nmap(lhs, rhs, desc)
                    vim.keymap.set('n', lhs, rhs, { desc = desc, buffer = bufnr })
                end
                nmap('[g', gs.prev_hunk, 'Previous hunk')
                nmap(']g', gs.next_hunk, 'Next hunk')
                nmap('<leader>gR', gs.reset_buffer, 'Reset buffer')
                nmap('<leader>gb', gs.blame_line, 'Blame line')
                nmap('<leader>gp', gs.preview_hunk, 'Preview hunk')
                nmap('<leader>gr', gs.reset_hunk, 'Reset hunk')
                nmap('<leader>gs', gs.stage_hunk, 'Stage hunk')
            end,
        },
    },
})

add {
    {
        src = 'linrongbin16/gitlinker.nvim',
        opts = function()
            return {
                router = gitlinker_router,
            }
        end,
        on_setup = function()
            vim.keymap.set({ 'n', 'v' }, '<leader>gc', '<cmd>GitLink<cr>', { desc = 'Yank git link' })
            vim.keymap.set({ 'n', 'v' }, '<leader>go', '<cmd>GitLink! blame<cr>', { desc = 'Open git link' })
        end,
    },
}
