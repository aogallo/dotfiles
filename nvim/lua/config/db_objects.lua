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
--
-- Listing integrity (specs/010-dbobjects-listing-integrity, issue #92): a listing is
-- only ever shown under a database the SERVER confirmed. The URL carries the
-- request; `db#adapter#sybase#confirm_database()` carries the fact, and every
-- label in this module derives from that fact, never from the request. A switch
-- the server rejects produces exactly one message and no listing at all — the
-- previous last-good reopen is gone, because re-presenting another database's
-- objects after a failure is the reported bug. The listing also states what it
-- covers (tables, views, procedures, functions, triggers — ASE's sysobjects.type
-- is char(2), so the covered values are U/V/P/SF/TR/XP) and reconciles what the
-- server reported against what is shown.

local M = {}

local db_context = require 'config.db_context'

-- Query draft registry (specs/011-query-buffer-tab-visibility, issue #96): owns
-- the display name, the connection binding and the text of a query buffer, so
-- opening one here produces a buffer that survives being closed and brought
-- back. Required (not lazy) so the module is loaded before any query can open.
local db_query_buffer = require 'config.db_query_buffer'

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
-- Called by: fetch_objects(), pick()
-- SQL: none
-- Args: url = connection URL string
-- Returns: boolean
-- Side effects: none
local is_sybase = db_context.is_sybase

-- url_database(url): owning database implied by a URL.
-- Kept exported by db_context for other callers; deliberately NOT used to label
-- anything here — a URL states a request, not a fact, and a label built from it
-- would be a claim the server never made (data-model.md §3, invariant I3).
local _url_database = db_context.url_database

-- scope_label(scope): readable database label for the picker.
-- Called by: pick(), start_listing(), apply_database_scope()
-- SQL: none
-- Args: scope = a confirmed scope, `{ database = string, source = 'verified' |
--   'none' }` (data-model.md §3)
-- Returns: the server-confirmed database name when the scope is `verified`,
--   otherwise 'login default'. A URL is deliberately NOT an argument: the label
--   must be an observation, never a request restated (invariant I3)
-- Side effects: none
local function scope_label(scope)
    if scope and scope.source == 'verified' and scope.database and scope.database ~= '' then
        return scope.database
    end
    return 'login default'
end

-- COVERED_KINDS: the object kinds the listing covers, in plain language.
-- Called by: prompt_for() (the picker header)
-- SQL: none (the adapter queries ASE's U/V/P/SF/TR/XP sysobjects types)
-- Args: none
-- Returns: string
-- Side effects: none
-- The system catalogue is deliberately NOT enumerated: it is thousands of rows
-- the developer cannot act on, for no benefit and real server load (FR-010).
-- Anything outside this set stays reachable through the direct-open entry.
local COVERED_KINDS = 'tables, views, procedures, functions, triggers'

-- url_from_buffer(buf): the connection a buffer is bound to.
-- Called by: default_url()
-- SQL: none
-- Args: buf = buffer number
-- Returns: URL string, or nil when no usable b:db context (string form, or the
--   {conn=…}/{db_url=…} table forms)
-- Side effects: none
local url_from_buffer = db_context.url_from_buffer

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
-- Called by: start_listing()
-- SQL: for `sybase://` the adapter's ONE-batch listing —
--   `select 'DDB~' + db_name()`,
--   `select 'DOBJ~' + name + '~' + convert(char(2), type) from sysobjects where
--    type in ('U','V','P','SF','TR','XP') order by name`, and
--   `select 'DCNT~' + count(*) …` over the same predicate. ASE stores
--   sysobjects.type as char(2), which is why the values are two characters and
--   not the single letters an earlier version matched on; other schemes use
--   dadbod's native tables() list when the adapter reports support
-- Args: url = connection URL string (its path is the database to search)
-- Returns: result table {rows, reported, excluded, diagnostics, count_known} as
--   the adapter returns it; {rows = {}, …} for an unsupported scheme
-- Side effects: none (read-only)
local function fetch_objects(url)
    local scheme = url:match '^([^:]+)://' or ''
    if scheme == 'sybase' then
        local result = vim.fn['db#adapter#sybase#objects'](url)
        if type(result) ~= 'table' or result.rows == nil then
            -- an adapter that still answers with a bare list
            result = { rows = result or {}, reported = 0, excluded = 0, diagnostics = {}, count_known = false }
        end
        return result
    end
    if vim.fn['db#adapter#supports'](url, 'tables') ~= 1 then
        return { rows = {}, reported = 0, excluded = 0, diagnostics = {}, count_known = false }
    end
    local rows = {}
    for _, name in ipairs(vim.fn['db#adapter#dispatch'](url, 'tables')) do
        table.insert(rows, { name = name, kind = 'table' })
    end
    return { rows = rows, reported = #rows, excluded = 0, diagnostics = {}, count_known = true }
end

-- reconcile(result): the self-describing counts of one listing.
-- Called by: build_listing()
-- SQL: none (arithmetic over what the listing batch already returned)
-- Args: result = the fetch_objects() return table
-- Returns: report = {reported, shown, excluded, count_known, partial}
--   invariant: shown + excluded = reported whenever count_known (I5)
--   partial is true when objects were withheld OR when the server's count row
--   never arrived — a listing that cannot prove its own total is never presented
--   as complete (FR-030, data-model.md §4)
-- Side effects: none
local function reconcile(result)
    local shown = #(result.rows or {})
    local count_known = result.count_known and true or false
    local reported = count_known and (tonumber(result.reported) or 0) or 0
    local excluded = 0
    if count_known and reported > shown then
        excluded = reported - shown
    end
    return {
        reported = reported,
        shown = shown,
        excluded = excluded,
        count_known = count_known,
        partial = (not count_known) or excluded > 0,
    }
end

-- build_listing(url, scope): fetch, reconcile and own one listing.
-- Called by: start_listing()
-- SQL: fetch_objects() (one client invocation)
-- Args: url = connection URL, scope = the confirmed scope that was established
--   BEFORE the fetch
-- Returns: listing = {rows, url, scope, report, diagnostics}; each row's
--   `database` is stamped from the confirmed scope, never from the URL's
--   requested name (contract §1.2, T013)
-- Side effects: none (read-only)
local function build_listing(url, scope)
    local result = fetch_objects(url)
    local rows = result.rows or {}
    if scope.source == 'verified' then
        for _, row in ipairs(rows) do
            row.database = scope.database
        end
    end
    return {
        rows = rows,
        url = url,
        scope = scope,
        report = reconcile(result),
        diagnostics = result.diagnostics or {},
    }
end

-- open_buffer(url, name, lines, database): show text in a query buffer.
--
-- MEASURED ROOT CAUSE (specs/011-query-buffer-tab-visibility, issue #96; R-0001,
-- R-0002, R-0011). Do not "simplify" this away without reading this first:
--   * `:bdelete` clears 'buflisted'. bufferline renders only buffers with
--     `listed == 1` (bufferline.nvim utils/init.lua:150) and exposes no option to
--     relax that, so a closed query buffer has no tab.
--   * Coming back does NOT undo it. `:buffer N`, `:bnext` and
--     `nvim_set_current_buf` leave the buffer unlisted; only `:edit <name>` and
--     fzf-lua's explicit `vim.bo[buf].buflisted = true` workaround re-list it.
--     That route-dependence is why the tab seemed to vanish "for some reason".
--   * `bufhidden = 'hide'` set below is inert here and is kept only because it is
--     not dead if `'hidden'` is ever turned off. `'hidden'` is on by default and
--     nvim/lua/config/options.lua never changes it (R-0004). It was investigated
--     as the source of the picker's `h` marker and ruled out: that marker tracks
--     `getbufinfo().hidden` for a loaded-but-not-displayed buffer, which is a
--     true statement about the buffer, not a bug (R-0004).
--   * `:bdelete` also unloads, which destroys `b:db` (buffer-local variables do
--     not survive an unload, R-0006) and the unsaved text (R-0007).
--   * Reopening the same query used to raise `Vim:E95: Buffer with this name
--     already exists` here, because this function created a second buffer for a
--     name the closed buffer still owned. The unhandled error skipped filetype,
--     `b:db` and focus, leaving an unnamed `[No Name]` orphan tab beside stale
--     content (R-0005).
--
-- The tab is restored by the additive-only guard in nvim/lua/config/buffers.lua.
-- Name allocation, the E95-safe reclaim, and recovery of the text and the
-- database binding all live in db_query_buffer.lua (FR-005, FR-012, FR-013,
-- FR-014) -- this function is now only the two call sites' way in, and the
-- duplicate-buffer path that caused E95 is gone.
--
-- Called by: open_list_query(), open_procedure_source()
-- SQL: none (the buffer is bound to url as b:db, so later :DB commands reuse
--   this connection and database)
-- Args: url = connection URL, name = object name, lines = buffer text,
--   database = owning database for the display name (may be nil)
-- Returns: the buffer number that was opened
-- Side effects: delegates to db_query_buffer.open(), which allocates or reclaims
--   a buffer, writes the text, sets filetype=sql and b:db, records a session-local
--   draft, ensures the buffer is listed and focuses it
local function open_buffer(url, name, lines, database)
    return db_query_buffer.open(url, name, lines, database)
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

-- report_failure(subject, causes, level): the single failure-reporting path.
-- Called by: apply_database_scope(), start_listing(), open_by_name()
-- SQL: none
-- Args: subject = the thing the message is about (a database, an object, the
--   connection), causes = the plausible causes, level = vim.log.levels.*
-- Returns: nothing
-- Side effects: exactly one vim.notify, so two paths can never report the same
--   failure twice (contract §3.3)
local function report_failure(subject, causes, level)
    vim.notify('DBObjects: ' .. subject .. ' — ' .. causes, level or vim.log.levels.ERROR)
end

-- open_by_name(listing): the direct-open entry.
-- Called by: pick() when the entry is chosen
-- SQL: none until the name is confirmed; then exactly the existing source read
--   (`db#adapter#sybase#source()`, unchanged — no new SQL, no new mode)
-- Args: listing = the current listing, whose scope MUST be `verified`
-- Returns: nothing (asynchronous; drives vim.ui.input)
-- Side effects: prompts for a name, then opens that object's source bound to
--   the confirmed database; a two-part name is rejected, an unresolvable name
--   yields one notice and no buffer, and cancelling is a pure no-op
--   (FR-015..FR-021, FR-035..FR-039)
local function open_by_name(listing)
    if listing.scope.source ~= 'verified' then
        report_failure(
            'opening an object by name needs a confirmed database first',
            'the connection carried no database, so there is nothing to read the object from — '
                .. 'choose a database with the entry at the top of the picker',
            vim.log.levels.WARN
        )
        return
    end
    vim.ui.input({ prompt = 'Object name: ' }, function(typed)
        -- Nothing has been sent to the server at this point, and nothing is sent
        -- until a non-empty name comes back (FR-018, invariant I7).
        if typed == nil then
            return
        end
        local name = vim.trim(typed)
        if name == '' then
            return
        end
        if name:find('.', 1, true) then
            report_failure(
                'cannot open the qualified name "' .. name .. '"',
                'only a bare object name is accepted — pick the database with the '
                    .. '"Database: … — change…" entry at the top of the picker, then search there',
                vim.log.levels.WARN
            )
            return
        end
        open_procedure_source(listing.url, { name = name, kind = 'object', database = listing.scope.database })
    end)
end

-- prompt_for(listing): the picker header.
-- Called by: pick()
-- SQL: none
-- Args: listing = the current listing
-- Returns: string — the confirmed scope, what the listing covers, and the
--   reconciliation (how many the server reported, how many are shown, how many
--   were left out). Dropped client lines are summarized once, trimmed, and only
--   when there are any (FR-029..FR-031)
-- Side effects: none
local function prompt_for(listing)
    local parts = { 'DB objects (' .. scope_label(listing.scope) .. ' — ' .. COVERED_KINDS .. ')' }
    local report = listing.report
    if not report.count_known then
        -- Without the server's own count there is no total to reconcile against,
        -- so the listing says it cannot prove itself rather than claiming to be
        -- whole (FR-030).
        table.insert(parts, 'the server sent no object count, so this listing may be incomplete')
    elseif report.excluded > 0 then
        table.insert(
            parts,
            'partial: '
                .. report.shown
                .. ' of '
                .. report.reported
                .. ' objects shown, '
                .. report.excluded
                .. ' not shown'
        )
    else
        table.insert(parts, report.shown .. ' of ' .. report.reported .. ' objects shown')
    end
    -- Dropped client lines are summarized once, capped at three samples and
    -- trimmed, so a chatty client can never dump an unbounded block (FR-029).
    local dropped = {}
    for _, diag in ipairs(listing.diagnostics) do
        if diag.reason and #dropped < 3 then
            table.insert(dropped, diag.text)
        end
    end
    if #dropped > 0 then
        table.insert(parts, 'server notes: ' .. table.concat(dropped, ' | '))
    end
    return table.concat(parts, '  ')
end

-- apply_database_scope(listing, database, origin): re-run the listing in a chosen DB.
-- Called by: choose_database() (picker row and typed name)
-- SQL: db#adapter#sybase#with_database() rebuilds the URL (rejected locally when
--   the name is outside [A-Za-z0-9_$#], so no request is made), then
--   db#adapter#sybase#confirm_database() asks the server which database is really
--   in effect, then the same one-batch objects() read
-- Args: listing = current listing, database = chosen name, origin = 'chosen' |
--   'typed' (data-model.md §2 — it picks the hint for a typo)
-- Returns: nothing
-- Side effects: opens the picker with the new listing when the server confirms
--   the database; otherwise emits exactly one message and opens NOTHING, so a
--   failure never re-presents the previous database's objects as the answer
--   (FR-002/FR-003/FR-007/FR-025, invariant I2/I4)
-- Forward declarations: pick <-> choose_database and pick <-> start_listing
-- form a cycle.
local pick
local start_listing

local function apply_database_scope(listing, database, origin)
    local scoped = vim.fn['db#adapter#sybase#with_database'](listing.url, database)
    if scoped == '' then
        report_failure(
            'cannot access database ' .. database .. ' (name must match [A-Za-z0-9_$#])',
            'the name was rejected locally, so nothing was sent to the server'
        )
        return
    end
    start_listing(scoped, vim.fn['db#adapter#sybase#confirm_database'](scoped), origin, listing.scope)
end

-- choose_database(listing): pick the database to search in.
-- Called by: pick() when the scope row is chosen
-- SQL: db#adapter#sybase#complete_database() lists the databases the login can
--   read (`select name from master..sysdatabases order by name`)
-- Args: listing = the current listing
-- Returns: nothing (asynchronous)
-- Side effects: one vim.ui.select of the readable databases (seeded with
--   `[use current: …]`) plus a typed-name path; a typed name equal to the
--   current scope warns instead of re-querying, and every cancel path returns
--   to the previous picker with no state change (FR-001/FR-009, FR-027)
local function choose_database(listing)
    local current_db = listing.scope.database
    local choices = {}
    if current_db and current_db ~= '' then
        table.insert(choices, { label = '[use current: ' .. current_db .. ']', database = current_db })
    end
    for _, d in ipairs(vim.fn['db#adapter#sybase#complete_database'](listing.url)) do
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
            pick(listing)
            return
        end
        if choice.typed then
            vim.ui.input({ prompt = 'Database name: ' }, function(typed)
                if typed == nil then
                    pick(listing)
                    return
                end
                local db = vim.trim(typed)
                if db == '' then
                    pick(listing)
                    return
                end
                if db == current_db then
                    vim.notify('DBObjects: ' .. db .. ' is already the active database scope', vim.log.levels.WARN)
                    pick(listing)
                    return
                end
                apply_database_scope(listing, db, 'typed')
            end)
            return
        end
        apply_database_scope(listing, choice.database, 'chosen')
    end)
end

-- pick(listing): the object picker itself (forward-declared, see above).
-- Called by: start_listing(), apply_database_scope(), choose_database()
-- SQL: none (the listing is already fetched)
-- Args: listing = {rows, url, scope, report, diagnostics}
-- Returns: nothing
-- Side effects: one vim.ui.select holding, in order: the `Database: <confirmed>
--   — change…` entry, the object rows, and — only on a verified scope — the
--   `Open object by name…` entry. The label reads the confirmed value, never the
--   requested one (invariant I3)
pick = function(listing)
    local items = {}
    if is_sybase(listing.url) then
        table.insert(items, { scope = true, database = scope_label(listing.scope) })
        vim.list_extend(items, listing.rows)
        if listing.scope.source == 'verified' then
            table.insert(items, { open_by_name = true })
        end
    else
        vim.list_extend(items, listing.rows)
    end
    vim.ui.select(items, {
        prompt = prompt_for(listing),
        format_item = function(row)
            if row.scope then
                return 'Database: ' .. scope_label(listing.scope) .. ' — change…'
            end
            if row.open_by_name then
                return 'Open object by name…'
            end
            local db = row.database and row.database ~= '' and (row.database .. ' ') or ''
            return row.kind .. '\t' .. db .. row.name
        end,
    }, function(row)
        if not row then
            return
        end
        if row.scope then
            choose_database(listing)
        elseif row.open_by_name then
            open_by_name(listing)
        else
            open_row(listing.url, row)
        end
    end)
end

-- surface_diagnostics(listing): report what the server said alongside the rows.
-- Called by: start_listing()
-- SQL: none
-- Args: listing = the built listing
-- Returns: nothing
-- Side effects: one WARN per distinct error-severity diagnostic, deduplicated —
--   never once per line, and never silently dropped (FR-022, data-model.md §6)
local function surface_diagnostics(listing)
    local seen = {}
    for _, diag in ipairs(listing.diagnostics) do
        if diag.severity == 'error' and not seen[diag.text] then
            seen[diag.text] = true
            vim.notify(
                'DBObjects: the server reported while listing ' .. scope_label(listing.scope) .. ': ' .. diag.text,
                vim.log.levels.WARN
            )
        end
    end
end

-- start_listing(url, confirmation, origin, previous): confirm the scope, then list.
-- Called by: M.open(), apply_database_scope()
-- SQL: the one-batch objects() read
-- Args: url = connection URL, confirmation = its confirm_database() result,
--   origin = 'chosen' | 'typed' | nil (the connection's own database) — it picks
--   the hint for a typo (data-model.md §2), previous = the scope in effect
--   before this attempt, so a rejection can name where the session stayed
-- Returns: nothing
-- Side effects: opens the picker on a confirmed or `login default` scope; on any
--   rejection emits exactly one message and opens nothing, leaving the caller's
--   scope untouched (FR-002/FR-003/FR-006/FR-025)
start_listing = function(url, confirmation, origin, previous)
    local scope
    if confirmation.result == 'confirmed' then
        scope = { database = confirmation.confirmed, source = 'verified' }
    elseif confirmation.result == 'no_database' then
        scope = { database = '', source = 'none' }
    elseif confirmation.result == 'not_attempted' then
        report_failure(
            'cannot read the catalog of ' .. (confirmation.requested ~= '' and confirmation.requested or url),
            'the ASE client is not installed or not on PATH for this connection, so nothing could '
                .. 'be confirmed — set g:db_sybase_client, or install sqsh (macOS) / isql (Windows)'
        )
        return
    elseif confirmation.result == 'rejected_absent' then
        local absent_hint = origin == 'typed'
                and 'check the spelling — it was typed, so it never appeared in the list of databases this login can read'
            or 'it is not in the list of databases this login can read'
        if origin then
            absent_hint = absent_hint
        else
            absent_hint =
                'check the name in the connection URL — it is not in the list of databases this login can read'
        end
        report_failure('database ' .. confirmation.requested .. ' does not exist on this server', absent_hint)
        return
    else
        local stayed = previous and scope_label(previous) or 'the login default database'
        report_failure(
            'database ' .. confirmation.requested .. ' exists but this login could not enter it',
            'the session stayed on '
                .. stayed
                .. ' — the login needs access to '
                .. confirmation.requested
                .. ' before its objects can be listed'
        )
        return
    end
    local listing = build_listing(url, scope)
    surface_diagnostics(listing)
    if listing.report.count_known and listing.report.shown == 0 then
        -- No objects is an EMPTY RESULT, not a failure: the picker still opens so
        -- the developer can change scope, and the header says "0 of 0" — visibly
        -- different from a message about a database that could not be read
        -- (FR-008).
        local where = scope.source == 'verified' and scope.database or 'the login default database'
        local how = scope.source == 'verified' and ' (the database was confirmed and read successfully)' or ''
        vim.notify('DBObjects: 0 objects in ' .. where .. ' (' .. COVERED_KINDS .. ')' .. how, vim.log.levels.INFO)
    end
    pick(listing)
end

-- M.open(name): entry point of :DBObjects [name].
-- Called by: nvim/plugin/database.lua (the :DBObjects command); recursion for
--   the connection chooser
-- SQL: for `sybase://` one confirmation batch, then one listing batch; other
--   schemes keep the native tables() list
-- Args: name = connection name from the command line, or nil to use the current
--   buffer's connection
-- Returns: nothing
-- Side effects: with no resolvable connection, offers a sorted vim.ui.select of
--   registered names (or one WARN when the registry is empty); with no objects,
--   one WARN; otherwise opens the picker under a confirmed scope
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
    if not is_sybase(url) then
        local result = fetch_objects(url)
        if vim.tbl_isempty(result.rows) then
            vim.notify('DBObjects: no objects returned for ' .. url, vim.log.levels.WARN)
            return
        end
        pick {
            rows = result.rows,
            url = url,
            scope = { database = '', source = 'none' },
            report = reconcile(result),
            diagnostics = result.diagnostics or {},
        }
        return
    end
    start_listing(url, vim.fn['db#adapter#sybase#confirm_database'](url))
end

return M
