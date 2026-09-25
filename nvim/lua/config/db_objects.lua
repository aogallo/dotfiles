-- Schema object search + Sybase procedure source loading (FR-022).
--
-- :DBObjects [name] opens an fzf-lua picker (vim.ui.select handler) listing
-- tables/views/procedures/functions from the resolved connection. For `sybase://`
-- URLs the listing comes from the custom adapter `objects()`/`source()`; other
-- schemes fall back to dadbod's native `tables()` (tables/collections only, no
-- procedure source action).
--
-- Database-scope control (specs/archive/2026-09-25-005-database-scope): for `sybase://` URLs the
-- picker leads with a `Database: <current> — change…` entry. Choosing it opens a
-- chooser of the databases the login can read (seeded with the connection's
-- current database) plus a typed-name path; picking one rebuilds the URL with
-- the chosen database as its path (`db#adapter#sybase#with_database()`) and
-- re-runs the listing inside that database. The scoped URL is threaded into
-- source loading, buffer binding (b:db), and save naming so everything executes
-- in the owning database. Default behavior (no scope choice) is unchanged.
--
-- DOCUMENTATION CONVENTION (see nvim/README.md, "Documenting a function"):
--   every function below carries a header with Purpose / Called by / SQL /
--   Args / Returns / Side effects. Required for new functions too.
--
-- Procedure save dialog (specs/archive/2026-09-23-002-procedure-save-dialog): after a
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

-- M.reset(): clear per-session state.
-- Called by: nvim/plugin/database.lua before re-sourcing, and by tests
-- SQL: none
-- Args: none
-- Returns: nothing
-- Side effects: none (kept for parity with the sibling DB modules)
function M.reset()
    -- no persistent state to reset; kept for consistency with sibling modules
end

-- Called once from nvim/plugin/database.lua at plugin source time with the
-- launch cwd (before any :cd). Defensive fallback: first-use getcwd().
-- M.setup(root): capture the directory every save dialog starts from.
-- Called by: nvim/plugin/database.lua at plugin source time with the launch cwd
-- SQL: none
-- Args: root = startup directory (falls back to getcwd() when nil)
-- Returns: nothing
-- Side effects: sets the module-level startup_root (read-only afterwards, so
--   the dialog never re-seeds from a later `:cd`)
function M.setup(root)
    startup_root = root or vim.fn.getcwd()
end

-- M.default_save_dir(): the directory the save dialog opens on every time.
-- Called by: resolve_typed_path(), M.run_save_flow(), and the tests
-- SQL: none
-- Args: none
-- Returns: string path — the captured startup_root, or getcwd() if setup()
--   never ran
-- Side effects: none
function M.default_save_dir()
    return startup_root or vim.fn.getcwd()
end

-- registry_urls(): the saved connection registry.
-- Called by: default_url(), M.open()
-- SQL: none (reads g:dbs, loaded by db_connections.lua)
-- Args: none
-- Returns: table<name, url> — g:dbs or {} before db_connections.lua loaded
-- Side effects: none
local function registry_urls()
    return vim.g.dbs or {}
end

-- is_sybase(url): does this URL use the custom Sybase adapter?
-- Called by: url_database(), fetch_objects(), pick()
-- SQL: none
-- Args: url = connection URL string
-- Returns: boolean
-- Side effects: none
local function is_sybase(url)
    return (url:match '^([^:]+)://' or '') == 'sybase'
end

-- url_database(url): owning database implied by a URL.
-- Called by: scope_label(), pick()
-- SQL: none (the path segment after host[:port], mirroring the adapter's
--   s:database() so the scope label and the row data always agree)
-- Args: url = connection URL string
-- Returns: database name, or nil for a non-Sybase URL / no path / empty path
-- Side effects: none
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

-- scope_label(url): readable database label for the picker.
-- Called by: pick() (prompt + scope row)
-- SQL: none
-- Args: url = connection URL string
-- Returns: the database name, or 'login default' when the URL carries none —
--   the same label for the prompt and the scope row (contract §1)
-- Side effects: none
local function scope_label(url)
    local db = url_database(url)
    return (db and db ~= '') and db or 'login default'
end

-- url_from_buffer(buf): the connection a buffer is bound to.
-- Called by: default_url()
-- SQL: none
-- Args: buf = buffer number
-- Returns: URL string, or nil when the buffer has no usable b:db context
--   (accepts both the string form and the {conn=…}/{db_url=…} table forms)
-- Side effects: none
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

-- default_url(name): which connection :DBObjects should use.
-- Called by: M.open()
-- SQL: none
-- Args: name = connection name given on the command line, or nil/'' for none
-- Returns: URL string, or nil when no name was given and the current buffer is
--   not bound to a connection
-- Side effects: none
local function default_url(name)
    if name and name ~= '' then
        return registry_urls()[name]
    end
    return url_from_buffer(vim.api.nvim_get_current_buf())
end

-- fetch_objects(url): list the objects of one database.
-- Called by: M.open(), apply_database_scope()
-- SQL: for `sybase://` the adapter's objects() query
--   (`select name, type from sysobjects where type in ('P','FN','IF','TF','V','U')
--   order by name`); other schemes use dadbod's native tables() list when the
--   adapter reports support
-- Args: url = connection URL string (its path is the database to search)
-- Returns: row[] — {name, kind, database?} entries; {} for unsupported schemes
--   or when the query fails
-- Side effects: none (read-only)
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

-- open_buffer(url, name, lines, database): show text in a new SQL buffer.
-- Called by: open_list_query(), open_procedure_source()
-- SQL: none (the buffer is bound to url as b:db, so later :DB commands reuse
--   this connection and database)
-- Args: url = connection URL, name = object name, lines = buffer text,
--   database = owning database for the display name (may be nil)
-- Returns: nothing (focuses the new buffer)
-- Side effects: creates a listed scratch buffer, names it
--   `<database>.<object>.sql`, sets filetype=sql and b:db, switches to it
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

-- open_list_query(url, row): show a table/view as a sample query.
-- Called by: open_row()
-- SQL: `select top 200 * from <name>` in the buffer (ASE-safe, no LIMIT; same
--   default the dadbod-ui table helper uses)
-- Args: url = connection URL, row = picker row for a table/view
-- Returns: nothing
-- Side effects: opens a buffer (see open_buffer)
local function open_list_query(url, row)
    -- ASE-safe default list query (no LIMIT), matching the dadbod-ui table helper.
    open_buffer(url, row.name, { 'select top 200 * from ' .. row.name }, row.database)
end

-- M.suggest_save_name(database, name): file name for a saved object source.
-- Called by: M.run_save_flow(); exported for the save-flow tests
-- SQL: none
-- Args: database = owning database (may be nil/''), name = object name
-- Returns: `<database>.<object>.sql`, or `<object>.sql` when the row carries no
--   database — same-named objects from different databases never collide (FR-006)
-- Side effects: none
function M.suggest_save_name(database, name)
    if database and database ~= '' then
        return database .. '.' .. name .. '.sql'
    end
    return name .. '.sql'
end

-- M.needs_confirmation(dir, filename): must we ask before overwriting?
-- Called by: M.run_save_flow(); exported for the save-flow tests
-- SQL: none
-- Args: dir = target directory, filename = target file name
-- Returns: boolean — true only when the file already exists (FR-007)
-- Side effects: none
function M.needs_confirmation(dir, filename)
    return vim.fn.filereadable(vim.fs.joinpath(dir, filename)) == 1
end

-- M.write_source(lines, dir, filename): write the opened source to disk.
-- Called by: M.run_save_flow(); exported for the save-flow tests
-- SQL: none
-- Args: lines = the exact buffer lines, dir = target directory,
--   filename = target file name
-- Returns: {ok=true, path=…} on success, {ok=false, error=…} when the write
--   failed or produced no readable file (FR-005/FR-009)
-- Side effects: writes the file
function M.write_source(lines, dir, filename)
    local path = vim.fs.joinpath(dir, filename)
    local ok, err = pcall(vim.fn.writefile, lines, path)
    if ok and vim.fn.filereadable(path) == 1 then
        return { ok = true, path = path }
    end
    return { ok = false, error = err or ('failed to write ' .. path) }
end

-- resolve_typed_path(typed): normalize a typed save path.
-- Called by: pick_save_target() (the `[type a path…]` branch)
-- SQL: none
-- Args: typed = raw user input
-- Returns: string path — normalized, with relative paths resolved against the
--   startup root so a saved file never depends on the current directory (FR-004)
-- Side effects: none
local function resolve_typed_path(typed)
    local target = vim.fs.normalize(typed)
    local is_relative = not vim.startswith(target, '/') and not vim.startswith(target, '~') and not target:match '^%a:'
    if is_relative then
        target = vim.fs.joinpath(M.default_save_dir(), target)
    end
    return target
end

-- pick_save_target(initial, on_done): choose the save directory.
-- Called by: M.run_save_flow()
-- SQL: none
-- Args: initial = directory to start from (the startup root), on_done = function
--   called with the chosen directory or nil on cancel
-- Returns: nothing (asynchronous; drives vim.ui.select/vim.ui.input)
-- Side effects: shows the picker chain — browse subdirectories with
--   vim.fs.dir + vim.ui.select, or type any path with vim.ui.input, offering to
--   create a missing directory; always re-seeded with the startup root, never a
--   previously chosen directory (FR-002/FR-003/FR-004/FR-008)
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

-- confirm_overwrite(path, on_done): ask before replacing an existing file.
-- Called by: M.run_save_flow() when M.needs_confirmation() is true
-- SQL: none
-- Args: path = full target path, on_done = function called with 'overwrite' or
--   'cancel'
-- Returns: nothing (asynchronous)
-- Side effects: one vim.ui.select with `Overwrite` / `Keep existing (cancel)`;
--   nothing is written unless 'overwrite' is chosen (FR-007/FR-008)
local function confirm_overwrite(path, on_done)
    vim.ui.select({ 'Overwrite', 'Keep existing (cancel)' }, {
        prompt = 'File already exists: ' .. path,
    }, function(choice)
        on_done(choice == 'Overwrite' and 'overwrite' or 'cancel')
    end)
end

-- M.run_save_flow(row, lines): the full save dialog for one object source.
-- Called by: open_procedure_source() right after the source buffer opens;
--   exported for the save-flow tests
-- SQL: none
-- Args: row = picker row (name + database), lines = the opened source lines
-- Returns: nothing (asynchronous)
-- Side effects: always asks for a target (seeded at the startup root), then
--   writes once — exactly one INFO notification with the full path on success,
--   one ERROR notification on failure; every cancel path is a no-op
--   (FR-001/FR-003/FR-005/FR-007/FR-008)
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

-- open_procedure_source(url, row): open and offer to save one procedure/function.
-- Called by: open_row()
-- SQL: the adapter's source() extraction — by default
--   `select convert(varchar(255), text) + '~' + case when text like '%' + char(10)
--   then ' ' else '+' end from syscomments where id = object_id('<name>') order by
--   number, colid2, colid` (reassembled client-side), or
--   `exec sp_helptext '<name>', NULL, NULL, 'showsql,noparams'` when
--   g:db_sybase_source_mode='showsql'
-- Args: url = connection URL, row = picker row for a procedure/function
-- Returns: nothing
-- Side effects: opens the source buffer and starts M.run_save_flow(); when the
--   text cannot be read (hidden/encrypted, no permission, missing object, no
--   client) opens nothing and emits one actionable WARN notice
local function open_procedure_source(url, row)
    local lines = vim.fn['db#adapter#sybase#source'](url, row.name)
    if vim.tbl_isempty(lines) then
        vim.notify(
            'DBObjects: cannot read the source of '
                .. row.name
                .. ' — its text may be hidden (sp_hidetext), the login may lack '
                .. 'select on syscomments.text, the object may not exist, or the '
                .. 'client is unavailable',
            vim.log.levels.WARN
        )
        return
    end
    open_buffer(url, row.name, lines, row.database)
    -- After the source opens, always ask where to save it (FR-001/FR-003).
    M.run_save_flow(row, lines)
end

-- open_row(url, row): dispatch one picker row to its open action.
-- Called by: pick() on selection
-- SQL: table/view → `select top 200 * from <name>`; procedure/function → the
--   source extraction in open_procedure_source()
-- Args: url = connection URL, row = picker row
-- Returns: nothing
-- Side effects: opens a buffer (and, for sources, the save dialog)
local function open_row(url, row)
    if row.kind == 'table' or row.kind == 'view' then
        open_list_query(url, row)
    else
        open_procedure_source(url, row)
    end
end

-- apply_database_scope(url, rows, database): re-run the listing in a chosen DB.
-- Called by: choose_database() (picker row and typed name)
-- SQL: db#adapter#sybase#with_database() rebuilds the URL, then the same
--   objects() query as fetch_objects() runs inside the new database
-- Args: url = current URL, rows = last-good listing, database = chosen database
-- Returns: nothing
-- Side effects: opens the picker with the new listing; an inaccessible name
--   ([A-Za-z0-9_$#] only) or an empty result emits exactly one actionable ERROR
--   and re-opens the last-good picker with the previous scope, never an empty
--   one (FR-002/FR-003, contract §2)
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

-- choose_database(url, rows, current_db): pick the database to search in.
-- Called by: pick() when the scope row is chosen
-- SQL: db#adapter#sybase#complete_database() lists the databases the login can
--   read (`select name from master..sysdatabases order by name`)
-- Args: url = current URL, rows = last-good listing, current_db = active scope
-- Returns: nothing (asynchronous)
-- Side effects: one vim.ui.select of the readable databases (seeded with
--   `[use current: …]`) plus a typed-name path; a typed name equal to the
--   current scope warns instead of re-querying, and every cancel path returns
--   to the previous picker with no state change (FR-001/FR-009)
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

-- pick(rows, url): the object picker itself (forward-declared, see above).
-- Called by: M.open(), apply_database_scope(), choose_database()
-- SQL: none (rows are already fetched)
-- Args: rows = listing to show, url = URL the listing belongs to
-- Returns: nothing
-- Side effects: one vim.ui.select; for `sybase://` URLs a leading
--   `Database: <db> — change…` row opens choose_database(), any other row opens
--   the object (open_row())
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

-- M.open(name): entry point of :DBObjects [name].
-- Called by: nvim/plugin/database.lua (the :DBObjects command); recursion for
--   the connection chooser
-- SQL: fetch_objects() for the resolved connection
-- Args: name = connection name from the command line, or nil to use the current
--   buffer's connection
-- Returns: nothing
-- Side effects: with no resolvable connection, offers a sorted vim.ui.select of
--   registered names (or one WARN when the registry is empty); with no objects,
--   one WARN; otherwise opens the picker
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
