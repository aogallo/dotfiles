-- Template for the user-owned database connection registry.
--
-- Copy this file to `nvim/db-connections.lua` (the default location resolved by
-- `nvim/lua/config/db_connections.lua`) or point NVIM_DB_CONNECTIONS at your own file:
--
--   export NVIM_DB_CONNECTIONS="$HOME/.config/nvim/db-connections.lua"
--
-- The real registry is gitignored; never commit credentials. Prefer $ENV_VAR
-- placeholders so secrets never land in the file at all.
--
-- Format: a name -> URL map. Supported schemes: sybase://, sqlserver://, mongodb://.
-- Values may be strings or functions returning a URL string (lazily resolved secrets).

return {
    -- sybase_prod = 'sybase://app_user:$SYBASE_PROD_PASS@prod_server/app_db?charset=iso_1',
    -- sybase_dev = function()
    --     return 'sybase://' .. vim.env.SYBASE_DEV_USER .. ':' .. vim.env.SYBASE_DEV_PASS .. '@dev_server/app_db'
    -- end,
    -- sqlserver_dev = 'sqlserver://dev_user:$SQLSRV_PASS@sql-dev:1433/AppDb',
    -- mongo_local = 'mongodb://localhost:27017/app_db',
}
