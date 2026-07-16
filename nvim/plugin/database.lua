local add = require('vim-pack').add

-- Database exploration and SQL query execution.
-- DB Configuration: https://github.com/sqls-server/sqls#db-configuration
add {
    { src = 'tpope/vim-dadbod', setup = false },
    {
        src = 'kristijanhusak/vim-dadbod-ui',
        setup = false,
        on_setup = function()
            vim.g.db_ui_use_nerd_fonts = 1
            vim.g.db_ui_save_location = vim.fn.stdpath 'data' .. '/db_ui'
        end,
    },
}
