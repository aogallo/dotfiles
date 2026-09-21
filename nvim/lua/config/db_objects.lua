-- Schema object search + Sybase procedure source loading (FR-022).
--
-- :DBObjects [name] opens an fzf-lua picker (vim.ui.select handler) listing
-- tables/views/procedures/functions from the resolved connection. For `sybase://`
-- URLs the listing comes from the custom adapter `objects()`/`source()`; other
-- schemes fall back to dadbod's native `tables()` (tables/collections only, no
-- procedure source action).

local M = {}

local function registry_urls()
    return vim.g.dbs or {}
end

function M.reset()
    -- no state to reset; kept for consistency with sibling modules
end

local function url_from_buffer(buf)
    local bdb = vim.b[buf].db
    if type(bdb) == 'string' then
        return bdb
    end
    if type(bdb) == 'table' then
        return bdb.conn or bdb.db_url
    end
    return nil
end

local function default_url(name)
    if name and name ~= '' then
        return registry_urls()[name]
    end
    return url_from_buffer(vim.api.nvim_get_current_buf())
end

local function fetch_objects(url)
    local scheme = url:match '^([^:]+)://' or ''
    if scheme == 'sybase' then
        return vim.fn['db#adapter#sybase#objects'](url)
    end
    if vim.fn['db#adapter#supports'](url, 'tables') ~= 1 then
        return {}
    end
    local rows = {}
    for _, name in ipairs(vim.fn['db#adapter#dispatch'](url, 'tables')) do
        table.insert(rows, { name = name, kind = 'table' })
    end
    return rows
end

local function open_buffer(url, name, lines)
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_name(buf, name .. '.sql')
    vim.api.nvim_buf_set_option(buf, 'bufhidden', 'hide')
    vim.api.nvim_buf_set_option(buf, 'filetype', 'sql')
    vim.b[buf].db = url
    vim.cmd('buffer ' .. buf)
end

local function open_list_query(url, name)
    -- ASE-safe default list query (no LIMIT), matching the dadbod-ui table helper.
    open_buffer(url, name, { 'select top 200 * from ' .. name })
end

local function open_procedure_source(url, name)
    local lines = vim.fn['db#adapter#sybase#source'](url, name)
    if vim.tbl_isempty(lines) then
        vim.notify(
            'DBObjects: no source returned for ' .. name .. ' (client or server unavailable)',
            vim.log.levels.WARN
        )
        return
    end
    open_buffer(url, name, lines)
end

local function open_row(url, row)
    if row.kind == 'table' or row.kind == 'view' then
        open_list_query(url, row.name)
    else
        open_procedure_source(url, row.name)
    end
end

local function pick(rows, url)
    vim.ui.select(rows, {
        prompt = 'DB objects (' .. url .. ')',
        format_item = function(row)
            return row.kind .. '\t' .. row.name
        end,
    }, function(row)
        if row then
            open_row(url, row)
        end
    end)
end

function M.open(name)
    local url = default_url(name)
    if not url or url == '' then
        local names = vim.tbl_keys(registry_urls())
        if vim.tbl_isempty(names) then
            vim.notify(
                'DBObjects: no registered connections (add nvim/db-connections.lua or set NVIM_DB_CONNECTIONS)',
                vim.log.levels.WARN
            )
            return
        end
        table.sort(names)
        vim.ui.select(names, { prompt = 'DB connection' }, function(selected)
            if selected then
                M.open(selected)
            end
        end)
        return
    end
    local rows = fetch_objects(url)
    if vim.tbl_isempty(rows) then
        vim.notify('DBObjects: no objects returned for ' .. url, vim.log.levels.WARN)
        return
    end
    pick(rows, url)
end

return M
