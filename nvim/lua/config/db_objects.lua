-- Schema object search + Sybase procedure source loading (FR-022).
--
-- :DBObjects [name] opens an fzf-lua picker (vim.ui.select handler) listing
-- tables/views/procedures/functions from the resolved connection. For `sybase://`
-- URLs the listing comes from the custom adapter `objects()`/`source()`; other
-- schemes fall back to dadbod's native `tables()` (tables/collections only, no
-- procedure source action).
--
-- Database-scope control (specs/005-database-scope): for `sybase://` URLs the
-- picker leads with a `Database: <current> — change…` entry. Choosing it opens a
-- chooser of the databases the login can read (seeded with the connection's
-- current database) plus a typed-name path; picking one rebuilds the URL with
-- the chosen database as its path (`db#adapter#sybase#with_database()`) and
-- re-runs the listing inside that database. The scoped URL is threaded into
-- source loading, buffer binding (b:db), and save naming so everything executes
-- in the owning database. Default behavior (no scope choice) is unchanged.
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

local function is_sybase(url)
    return (url:match '^([^:]+)://' or '') == 'sybase'
end

-- Owning database implied by a URL: the path segment after host[:port] ('' when
-- absent, nil for non-Sybase URLs). Mirrors the adapter's s:database() so the
-- scope label and the row data always agree.
local function url_database(url)
    if not is_sybase(url) then
        return nil
    end
    local rest = url:match '^sybase://[^/]*/(.*)$'
    if not rest then
        return nil
    end
    local db = rest:match '^([^?]*)'
    if db == '' then
        return nil
    end
    return db
end

-- Readable scope label (FR-001): the database name read from the URL, or
-- 'login default' when the connection has none. Used by the picker header and
-- the scope row so both always show the same label (contract §1).
local function scope_label(url)
    local db = url_database(url)
    return (db and db ~= '') and db or 'login default'
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

local function open_buffer(url, name, lines, database)
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    local display = database and database ~= '' and (database .. '.' .. name .. '.sql') or (name .. '.sql')
    vim.api.nvim_buf_set_name(buf, display)
    vim.api.nvim_buf_set_option(buf, 'bufhidden', 'hide')
    vim.api.nvim_buf_set_option(buf, 'filetype', 'sql')
    vim.b[buf].db = url
    vim.cmd('buffer ' .. buf)
end

local function open_list_query(url, row)
    -- ASE-safe default list query (no LIMIT), matching the dadbod-ui table helper.
    open_buffer(url, row.name, { 'select top 200 * from ' .. row.name }, row.database)
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
                return
            end
            vim.notify('DBObjects: saved ' .. result.path, vim.log.levels.INFO)
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
    open_buffer(url, row.name, lines, row.database)
    -- After the source opens, always ask where to save it (FR-001/FR-003).
    M.run_save_flow(row, lines)
end

local function open_row(url, row)
    if row.kind == 'table' or row.kind == 'view' then
        open_list_query(url, row)
    else
        open_procedure_source(url, row)
    end
end

-- Apply a chosen database: rebuild the URL with it as the path and re-run the
-- listing inside it (FR-002). Invalid/inaccessible or empty results surface
-- exactly one actionable message and never an empty picker: the picker re-opens
-- on the last-good listing with the previous scope (FR-003, contract §2).
local pick -- forward declaration: pick <-> choose_database form a cycle

local function apply_database_scope(url, rows, database)
    local scoped = vim.fn['db#adapter#sybase#with_database'](url, database)
    if scoped == '' then
        vim.notify(
            'DBObjects: cannot access database ' .. database .. ' (name must match [A-Za-z0-9_$#])',
            vim.log.levels.ERROR
        )
        pick(rows, url)
        return
    end
    local scoped_rows = fetch_objects(scoped)
    if vim.tbl_isempty(scoped_rows) then
        vim.notify('DBObjects: no objects returned for ' .. database, vim.log.levels.ERROR)
        pick(rows, url)
        return
    end
    pick(scoped_rows, scoped)
end

-- Database chooser (FR-001): the databases the login can read (seeded with the
-- connected database) plus a typed-name path. Cancelling returns to the previous
-- picker with no state change (FR-009).
local function choose_database(url, rows, current_db)
    local choices = {}
    if current_db and current_db ~= '' then
        table.insert(choices, { label = '[use current: ' .. current_db .. ']', database = current_db })
    end
    for _, d in ipairs(vim.fn['db#adapter#sybase#complete_database'](url)) do
        if d ~= current_db then
            table.insert(choices, { label = d, database = d })
        end
    end
    table.insert(choices, { label = '[type a database name…]', typed = true })
    vim.ui.select(choices, {
        prompt = 'Database scope for object search',
        format_item = function(c)
            return c.label
        end,
    }, function(choice)
        if not choice then
            pick(rows, url)
            return
        end
        if choice.typed then
            vim.ui.input({ prompt = 'Database name: ' }, function(typed)
                if typed == nil then
                    pick(rows, url)
                    return
                end
                local db = vim.trim(typed)
                if db == '' then
                    pick(rows, url)
                    return
                end
                if db == current_db then
                    vim.notify('DBObjects: ' .. db .. ' is already the active database scope', vim.log.levels.WARN)
                    pick(rows, url)
                    return
                end
                apply_database_scope(url, rows, db)
            end)
            return
        end
        apply_database_scope(url, rows, choice.database)
    end)
end

pick = function(rows, url)
    local current_db = url_database(url)
    local items = rows
    if is_sybase(url) then
        items = { { scope = true, database = current_db } }
        vim.list_extend(items, rows)
    end
    vim.ui.select(items, {
        prompt = 'DB objects (' .. scope_label(url) .. ')',
        format_item = function(row)
            if row.scope then
                return 'Database: ' .. scope_label(url) .. ' — change…'
            end
            local db = row.database and row.database ~= '' and (row.database .. ' ') or ''
            return row.kind .. '\t' .. db .. row.name
        end,
    }, function(row)
        if row then
            if row.scope then
                choose_database(url, rows, current_db)
            else
                open_row(url, row)
            end
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
