require 'config.db_connections'

local db_objects = require 'config.db_objects'
local db_results = require 'config.db_results'

local add = require('vim-pack').add

-- Database exploration and SQL query execution.
-- DB Configuration: https://github.com/sqls-server/sqls#db-configuration
-- Connection registry: nvim/lua/config/db_connections.lua + nvim/db-connections.example.lua
add {
    { src = 'tpope/vim-dadbod', setup = false },
    {
        src = 'kristijanhusak/vim-dadbod-ui',
        setup = false,
        on_setup = function()
            vim.g.db_ui_use_nerd_fonts = 1
            vim.g.db_ui_save_location = vim.fn.stdpath 'data' .. '/db_ui'
            -- Route dadbod-ui notices through the native Neovim notification
            -- system (vim.notify, displayed by Snacks) instead of the editor
            -- overlay (specs/006-dbui-query-results, US2).
            vim.g.db_ui_use_nvim_notify = true
            -- Sybase ASE has no LIMIT; dadbod-ui's default helper uses "limit 200".
            -- Merge + re-assign the whole table: nested vim.g writes do not persist.
            local helpers = vim.deepcopy(vim.g.db_ui_table_helpers or {})
            helpers.sybase = { List = 'select top 200 * from {table}' }
            vim.g.db_ui_table_helpers = helpers
        end,
    },
    { src = 'kristijanhusak/vim-dadbod-completion', setup = false },
}

-- Schema object search (FR-022): :DBObjects [name] with completion over the
-- registry connection names. Resolution: explicit name > current buffer's
-- dadbod URL (b:db) > picker over g:dbs > warn.
-- The procedure save dialog's default target (specs/002-procedure-save-dialog,
-- FR-002) is the directory where Neovim was started: captured here at plugin
-- source time, before any :cd, and handed to db_objects.setup().
db_objects.setup(vim.fn.getcwd())

-- `<leader>qr` summon: record dadbod's finished query results and let the keymap
-- refocus/reopen the last one (specs/006-dbui-query-results, US1).
db_results.setup()

vim.api.nvim_create_user_command('DBObjects', function(args)
    db_objects.open(args.fargs[1])
end, {
    nargs = '?',
    complete = function()
        return vim.tbl_keys(vim.g.dbs or {})
    end,
})
