-- Schema object search + Sybase procedure source loading (FR-022).
--
-- :DBObjects [name] opens an fzf-lua picker (vim.ui.select handler) listing
-- tables/views/procedures/functions from the resolved connection. For `sybase://`
-- URLs the listing comes from the custom adapter `objects()`/`source()`; other
-- schemes fall back to dadbod's native `tables()` (tables/collections only, no
-- procedure source action).
--
-- Procedure save dialog (specs/002-procedure-save-dialog): after a
-- procedure/function source opens, the user is always asked where to save its
-- text to disk. Default target is the directory where Neovim was started
-- (plugin source time, before any `:cd`), captured via M.setup(). Saved file
-- names are `<database>.<object>.sql` (database-qualified so same-named objects
-- from different databases never collide) and an existing same-named file is
-- never overwritten silently. Cancelling leaves everything untouched.

local M = {}

-- Startup root (FR-002): directory where Neovim was started. Read-only after
-- setup(); the dialog's initial path on every invocation, never a previously
-- chosen directory (FR-003).
local startup_root = nil

function M.reset()
    -- no persistent state to reset; kept for consistency with sibling modules
end

-- Called once from nvim/plugin/database.lua at plugin source time with the
-- launch cwd (before any :cd). Defensive fallback: first-use getcwd().
function M.setup(root)
    startup_root = root or vim.fn.getcwd()
end

function M.default_save_dir()
    return startup_root or vim.fn.getcwd()
end

local function registry_urls()
    return vim.g.dbs or {}
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

-- File name (FR-006): `<owning-database>.<object>.sql`, falling back to
-- `<object>.sql` when the row carries no database (single-DB listing).
function M.suggest_save_name(database, name)
    if database and database ~= '' then
        return database .. '.' .. name .. '.sql'
    end
    return name .. '.sql'
end

-- Overwrite guard (FR-007): true only when the target file already exists.
function M.needs_confirmation(dir, filename)
    return vim.fn.filereadable(vim.fs.joinpath(dir, filename)) == 1
end

-- Byte-exact write (FR-005): the saved file equals the source `lines`; errors
-- return a single actionable message instead of crashing (FR-009).
function M.write_source(lines, dir, filename)
    local path = vim.fs.joinpath(dir, filename)
    local ok, err = pcall(vim.fn.writefile, lines, path)
    if ok and vim.fn.filereadable(path) == 1 then
        return { ok = true, path = path }
    end
    return { ok = false, error = err or ('failed to write ' .. path) }
end

-- Resolve a typed path: normalize (~ expansion, separators) and make relative
-- paths absolute against the startup root (FR-004).
local function resolve_typed_path(typed)
    local target = vim.fs.normalize(typed)
    local is_relative = not vim.startswith(target, '/') and not vim.startswith(target, '~') and not target:match '^%a:'
    if is_relative then
        target = vim.fs.joinpath(M.default_save_dir(), target)
    end
    return target
end

-- Async directory picker (FR-004): browse available subdirectories via
-- vim.fs.dir + vim.ui.select, or type an arbitrary path (vim.ui.input). The
-- callback receives the chosen directory, or nil on cancel (FR-008). Seeded
-- with the startup root on every invocation (FR-002/FR-003).
local function pick_save_target(initial, on_done)
    local current = vim.fs.normalize(initial)
    local function browse()
        local dirs = {}
        for name, entry_type in vim.fs.dir(current) do
            if entry_type == 'directory' then
                table.insert(dirs, name)
            end
        end
        table.sort(dirs)
        local choices = {
            { label = '[save here: ' .. current .. ']', tag = 'here' },
        }
        for _, d in ipairs(dirs) do
            table.insert(choices, { label = d .. '/', tag = 'dir', dir = vim.fs.joinpath(current, d) })
        end
        table.insert(choices, { label = '..  (parent)', tag = 'up' })
        table.insert(choices, { label = '[type a path…]', tag = 'type' })
        vim.ui.select(choices, {
            prompt = 'Save procedure to',
            format_item = function(c)
                return c.label
            end,
        }, function(choice)
            if not choice then
                on_done(nil)
                return
            end
            if choice.tag == 'up' then
                current = vim.fs.dirname(current)
                browse()
            elseif choice.tag == 'dir' then
                current = choice.dir
                browse()
            elseif choice.tag == 'here' then
                on_done(current)
            elseif choice.tag == 'type' then
                vim.ui.input({ prompt = 'Type a path: ', default = current }, function(typed)
                    if typed == nil then
                        browse()
                        return
                    end
                    local target = resolve_typed_path(typed)
                    if vim.fn.isdirectory(target) == 1 then
                        on_done(target)
                        return
                    end
                    vim.ui.select({ 'Create directory', 'Cancel' }, {
                        prompt = 'Directory does not exist: ' .. target,
                    }, function(choice2)
                        if choice2 == 'Create directory' then
                            vim.fn.mkdir(target, 'p')
                            on_done(target)
                        else
                            browse()
                        end
                    end)
                end)
            end
        end)
    end
    browse()
end

-- Overwrite confirm (FR-007): explicit choice before replacing an existing
-- file; 'cancel' aborts with zero side effects (FR-008).
local function confirm_overwrite(path, on_done)
    vim.ui.select({ 'Overwrite', 'Keep existing (cancel)' }, {
        prompt = 'File already exists: ' .. path,
    }, function(choice)
        on_done(choice == 'Overwrite' and 'overwrite' or 'cancel')
    end)
end

-- Save flow: pick target (always, seeded at startup root) → check collision →
-- write. Every abort path is a no-op (FR-008). Exported as M.run_save_flow for
-- wiring in the selection handler below.
function M.run_save_flow(row, lines)
    pick_save_target(M.default_save_dir(), function(dir)
        if not dir then
            return
        end
        local filename = M.suggest_save_name(row.database, row.name)
        local function save()
            local result = M.write_source(lines, dir, filename)
            if not result.ok then
                vim.notify('DBObjects: ' .. result.error, vim.log.levels.ERROR)
            end
        end
        if M.needs_confirmation(dir, filename) then
            confirm_overwrite(vim.fs.joinpath(dir, filename), function(verdict)
                if verdict == 'overwrite' then
                    save()
                end
            end)
        else
            save()
        end
    end)
end

local function open_procedure_source(url, row)
    local lines = vim.fn['db#adapter#sybase#source'](url, row.name)
    if vim.tbl_isempty(lines) then
        vim.notify(
            'DBObjects: no source returned for ' .. row.name .. ' (client or server unavailable)',
            vim.log.levels.WARN
        )
        return
    end
    open_buffer(url, row.name, lines)
    -- After the source opens, always ask where to save it (FR-001/FR-003).
    M.run_save_flow(row, lines)
end

local function open_row(url, row)
    if row.kind == 'table' or row.kind == 'view' then
        open_list_query(url, row.name)
    else
        open_procedure_source(url, row)
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
