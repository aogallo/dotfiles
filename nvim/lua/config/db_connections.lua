local M = {}

local modname = 'db_connections'
local warned = false

local function warn(msg)
    if warned then
        return
    end
    warned = true
    vim.notify(modname .. ': ' .. msg, vim.log.levels.WARN)
end

local function resolve_path()
    local env_path = vim.env.NVIM_DB_CONNECTIONS
    if env_path and vim.fn.filereadable(env_path) == 1 then
        return env_path
    end
    return vim.fn.stdpath 'config' .. '/db-connections.lua'
end

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
