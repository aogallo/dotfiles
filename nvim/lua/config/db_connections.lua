-- Connection registry loader: the list of saved connections shown by :DBUI and
-- by every :DB* command. The registry is a plain Lua file that returns a table;
-- it is loaded at startup and reloaded whenever a `dbui` buffer is entered so
-- file edits show up without a restart.
--
-- DOCUMENTATION CONVENTION (see nvim/README.md, "Documenting a function"):
--   every function carries a header with Purpose / Called by / SQL / Args /
--   Returns / Side effects. Required for new functions too.
local M = {}

local modname = 'db_connections'
local warned = false

-- warn(msg): notify once per session, prefixed with the module name.
-- Called by: M.load() when the registry cannot be read
-- SQL: none
-- Args: msg = one-line warning text
-- Returns: nothing (returns early when this session already warned)
-- Side effects: sets the once-flag and shows a WARN notification
local function warn(msg)
    if warned then
        return
    end
    warned = true
    vim.notify(modname .. ': ' .. msg, vim.log.levels.WARN)
end

-- resolve_path(): pick the registry file to load.
-- Called by: M.load()
-- SQL: none
-- Args: none
-- Returns: string path — $NVIM_DB_CONNECTIONS when it points at a readable
--   file, otherwise <stdpath 'config'>/db-connections.lua
-- Side effects: none
local function resolve_path()
    local env_path = vim.env.NVIM_DB_CONNECTIONS
    if env_path and vim.fn.filereadable(env_path) == 1 then
        return env_path
    end
    return vim.fn.stdpath 'config' .. '/db-connections.lua'
end

-- M.load(): (re)read the registry into g:dbs and return it.
-- Called by: this module at source time; the BufEnter autocmd below when
--   filetype=dbui; the DB commands that need the connection list
-- SQL: none (loads a Lua file)
-- Args: none
-- Returns: table registry — g:dbs contents; {} when the file is missing,
--   unparseable, or does not return a table (one warning per failure mode)
-- Side effects: overwrites g:dbs; may notify once per session
function M.load()
    local path = resolve_path()
    local registry = {}
    if vim.fn.filereadable(path) == 1 then
        local chunk = loadfile(path)
        if chunk then
            local ok, loaded = pcall(chunk)
            if ok and type(loaded) == 'table' then
                registry = loaded
            else
                warn('registry at ' .. path .. ' must return a table')
            end
        else
            warn('could not parse registry at ' .. path)
        end
    end
    vim.g.dbs = registry
    return registry
end

M.load()

local group = vim.api.nvim_create_augroup('DbConnections', { clear = true })

vim.api.nvim_create_autocmd('BufEnter', {
    group = group,
    desc = 'Reload registry so :DBUI + R reflects file edits without restart (FR-006)',
    callback = function()
        if vim.bo.filetype ~= 'dbui' then
            return
        end
        M.load()
    end,
})

return M
