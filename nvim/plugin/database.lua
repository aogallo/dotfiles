require 'config.db_connections'

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
            -- Sybase ASE has no LIMIT; dadbod-ui's default helper uses "limit 200".
            -- Merge + re-assign the whole table: nested vim.g writes do not persist.
            local helpers = vim.deepcopy(vim.g.db_ui_table_helpers or {})
            helpers.sybase = 'select top 200 * from {table}'
            vim.g.db_ui_table_helpers = helpers
        end,
    },
    { src = 'kristijanhusak/vim-dadbod-completion', setup = false },
}

-- Schema object search (FR-022): :DBObjects [name] with completion over the
-- registry connection names. Resolution: explicit name > current buffer's
-- dadbod URL (b:db) > picker over g:dbs > warn.
vim.api.nvim_create_user_command('DBObjects', function(args)
    local db_objects = require 'config.db_objects'
    db_objects.open(args.fargs[1])
end, {
    nargs = '?',
    complete = function()
        return vim.tbl_keys(vim.g.dbs or {})
    end,
})
