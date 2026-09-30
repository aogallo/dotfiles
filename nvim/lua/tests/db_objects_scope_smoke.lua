-- Database-scope + listing-integrity smoke test (specs/010-dbobjects-listing-integrity,
-- issue #92, quickstart §3.2/§3.3/§3.4/§3.5). Headless coverage of the object-search
-- scope flow:
--   - contract: the REAL db#adapter#sybase#with_database() swaps the URL path
--     and preserves auth/host/port/params; invalid names (incl. '%') return ''
--   - scope: confirm_database() establishes the scope BEFORE the listing, and
--     every label is derived from the confirmed value, never the requested one
--   - failure: each rejection yields exactly ONE message and NO listing (the
--     last-good reopen is gone — re-presenting another database's objects after
--     a failure is the reported bug)
--   - direct-open: offered only on a verified scope, issues nothing until the
--     name is confirmed, and reuses the existing source read
--   - reconciliation: the header states the covered kinds and the
--     reported/shown/excluded counts
--   - preserved: chooser cancel, prompt cancel and re-selecting the active
--     database stay non-destructive no-ops
-- Adapter entry points that would run live queries are stubbed; db#url#parse
-- is stubbed so the REAL with_database() runs against canned URLs headlessly.
-- Exits with code 1 via :cquit on any assertion failure.

local M = require 'config.db_objects'

local select_calls = {}
local input_calls = {}
local notices = {}

local function fail(ok, name, got, want)
    if ok then
        vim.print('PASS ' .. name)
        return
    end
    vim.print('FAIL ' .. name)
    vim.print('  got:  ' .. vim.inspect(got))
    vim.print('  want: ' .. vim.inspect(want))
    vim.cmd 'cquit'
end

local function next_select()
    if #select_calls == 0 then
        vim.print 'FAIL expected another vim.ui.select call (none pending)'
        vim.cmd 'cquit'
    end
    return table.remove(select_calls, 1)
end

local function no_select(what)
    if #select_calls == 0 then
        vim.print('PASS ' .. what)
        return
    end
    fail(false, what, vim.inspect(select_calls[1]), 'no picker at all')
end

local function next_input()
    if #input_calls == 0 then
        vim.print 'FAIL expected a vim.ui.input call (none pending)'
        vim.cmd 'cquit'
    end
    return table.remove(input_calls, 1)
end

local function no_input(what)
    if #input_calls == 0 then
        vim.print('PASS ' .. what)
        return
    end
    fail(false, what, vim.inspect(input_calls[1]), 'no prompt at all')
end

local function pick_matching(items, predicate)
    local found
    for _, item in ipairs(items) do
        if predicate(item) then
            found = item
            break
        end
    end
    if not found then
        vim.print('FAIL could not find expected chooser item in ' .. vim.inspect(items))
        vim.cmd 'cquit'
    end
    return found
end

local function find_item(items, predicate)
    for _, item in ipairs(items) do
        if predicate(item) then
            return item
        end
    end
end

-- --- adapter + ui stubs ------------------------------------------------

local URL_MAIN = 'sybase://alice:p@h:5000/main_db?charset=iso_1'
local URL_NODEFAULT = 'sybase://alice:p@h:5000'

local PARSE = {
    [URL_MAIN] = {
        scheme = 'sybase',
        user = 'alice',
        password = 'p',
        host = 'h',
        port = '5000',
        path = '/main_db',
        params = { charset = 'iso_1' },
    },
    [URL_NODEFAULT] = {
        scheme = 'sybase',
        user = 'alice',
        password = 'p',
        host = 'h',
        port = '5000',
        path = '/',
        params = {},
    },
    ['sybase://h/main_db'] = { scheme = 'sybase', host = 'h', path = '/main_db', params = {} },
    ['sybase://h'] = { scheme = 'sybase', host = 'h', path = '/', params = {} },
}

vim.fn['db#url#parse'] = function(u)
    local parsed = PARSE[u]
    if not parsed then
        vim.print('FAIL: db#url#parse stub missing canned entry for ' .. vim.inspect(u))
        vim.cmd 'cquit'
    end
    return parsed
end

local OBJECTS = {
    main_db = {
        { name = 'usp_one', kind = 'procedure', database = 'main_db' },
        { name = 't_users', kind = 'table', database = 'main_db' },
    },
    other_db = {
        { name = 'usp_two', kind = 'procedure', database = 'other_db' },
    },
    my_schema_db = {
        { name = 'usp_three', kind = 'procedure', database = 'my_schema_db' },
    },
    empty_db = {},
}

-- A database the server knows, but this login cannot enter: the switch is
-- rejected and the session stays on the login default.
local CONFIRM = {
    main_db = { requested = 'main_db', confirmed = 'main_db', result = 'confirmed', exists = 1 },
    other_db = { requested = 'other_db', confirmed = 'other_db', result = 'confirmed', exists = 1 },
    my_schema_db = { requested = 'my_schema_db', confirmed = 'my_schema_db', result = 'confirmed', exists = 1 },
    empty_db = { requested = 'empty_db', confirmed = 'empty_db', result = 'confirmed', exists = 1 },
    absent_db = { requested = 'absent_db', confirmed = '', result = 'rejected_absent', exists = 0 },
    forbidden_db = { requested = 'forbidden_db', confirmed = '', result = 'rejected_forbidden', exists = 1 },
    denied_db = { requested = 'denied_db', confirmed = '', result = 'rejected_forbidden', exists = 1 },
    -- The server answered with a DIFFERENT name than the one requested. The
    -- label must never read as the requested database (invariant I3).
    mismatch_db = { requested = 'mismatch_db', confirmed = 'other_db', result = 'confirmed', exists = 1 },
    no_client_db = { requested = 'no_client_db', confirmed = '', result = 'not_attempted', exists = '' },
}

local objects_calls = 0
local confirm_calls = 0
local source_calls = 0

local function db_of(url)
    return url:match '^sybase://[^/]*/([^?]*)'
end

-- db#adapter#sybase#objects now answers {rows, reported, excluded,
-- diagnostics, count_known}; a row is never built here — the picker owns that.
vim.fn['db#adapter#sybase#objects'] = function(url)
    objects_calls = objects_calls + 1
    local db = db_of(url)
    local rows = {}
    for _, r in ipairs(OBJECTS[db] or {}) do
        table.insert(rows, vim.deepcopy(r))
    end
    local extra = { diagnostics = {}, count_known = true, reported = #rows, excluded = 0 }
    if db == 'mismatch_db' then
        -- The catalog came back from somewhere else; say so instead of lying.
        extra.diagnostics =
            { { text = "Changed database context to 'other_db'.", severity = 'info', reason = 'no_marker' } }
        extra.reported = #rows + 4
        extra.excluded = 4
    end
    extra.rows = rows
    return extra
end

vim.fn['db#adapter#sybase#confirm_database'] = function(url)
    confirm_calls = confirm_calls + 1
    local db = db_of(url)
    return CONFIRM[db] or { requested = '', confirmed = '', result = 'no_database', exists = '' }
end

vim.fn['db#adapter#sybase#complete_database'] = function()
    return { 'main_db', 'other_db', 'empty_db' }
end

local unreadable = {}
vim.fn['db#adapter#sybase#source'] = function(_, name)
    source_calls = source_calls + 1
    if unreadable[name] then
        return {}
    end
    return { 'create procedure ' .. name .. ' as', '  select 1', 'go' }
end

vim.ui.select = function(items, opts, cb)
    table.insert(select_calls, { items = items, opts = opts, cb = cb })
end
vim.ui.input = function(opts, cb)
    table.insert(input_calls, { opts = opts, cb = cb })
end
vim.notify = function(msg, level)
    table.insert(notices, { msg = msg, level = level })
end

local files = vim.api.nvim_get_runtime_file('autoload/db/adapter/sybase.vim', false)
vim.cmd('source ' .. files[#files])

local with_database = vim.fn['db#adapter#sybase#with_database']

-- --- contract: with_database() (unchanged by this feature) ----------------

local url_dict = {
    scheme = 'sybase',
    user = 'u',
    password = 'p',
    host = 'h',
    port = '5000',
    path = '/db',
    params = { charset = 'iso_1' },
}
local built = with_database(url_dict, 'other')
fail(
    built == 'sybase://u:p@h:5000/other?charset=iso_1',
    'with_database swaps the path and preserves auth/host/port/params',
    built,
    'sybase://u:p@h:5000/other?charset=iso_1'
)
local minimal = with_database({ scheme = 'sybase', host = 'h', path = '/' }, 'db2')
fail(minimal == 'sybase://h/db2', 'with_database works without auth/port/params', minimal, 'sybase://h/db2')
local via_string = with_database(URL_MAIN, 'other_db')
fail(
    via_string == 'sybase://alice:p@h:5000/other_db?charset=iso_1',
    'with_database rebuilds from a string URL',
    via_string,
    'sybase://alice:p@h:5000/other_db?charset=iso_1'
)
fail(
    with_database(url_dict, 'bad%name') == '',
    'with_database rejects % (cross-database scans stay out of scope)',
    with_database(url_dict, 'bad%name'),
    "''"
)
fail(
    with_database(url_dict, 'a/b') == '',
    'with_database rejects path separators',
    with_database(url_dict, 'a/b'),
    "''"
)
fail(
    with_database(url_dict, 'spaced name') == '',
    'with_database rejects unsafe characters',
    with_database(url_dict, 'spaced name'),
    "''"
)

-- --- flow fixtures -------------------------------------------------------

local buf0 = vim.api.nvim_create_buf(true, false)
vim.b[buf0].db = URL_MAIN
vim.api.nvim_set_current_buf(buf0)

local function open_objects()
    M.open()
    return next_select()
end

-- The last row of a sybase picker is the direct-open entry; the row before the
-- object rows is the scope entry.
local function direct_open_entry(items)
    return find_item(items, function(i)
        return i.open_by_name == true
    end)
end

-- --- US1: the listing belongs to the database the server confirmed --------

local pick1 = open_objects()
fail(
    pick1.opts.prompt:find('main_db', 1, true) ~= nil,
    'object picker prompt shows the confirmed database',
    pick1.opts.prompt,
    '<contains main_db>'
)
fail(pick1.items[1].scope == true, 'picker leads with the scope entry', pick1.items[1], '{ scope = true }')
fail(
    pick1.items[1].database == 'main_db',
    'scope entry shows the confirmed database',
    pick1.items[1].database,
    'main_db'
)
fail(
    #pick1.items == 2 + #OBJECTS.main_db,
    'default listing is the confirmed database (scope + objects + direct-open)',
    #pick1.items,
    4
)
fail(
    direct_open_entry(pick1.items) ~= nil,
    'the direct-open entry is offered on a verified scope',
    vim.inspect(pick1.items),
    'one open_by_name entry'
)
fail(
    pick1.opts.prompt:find('triggers', 1, true) ~= nil and pick1.opts.prompt:find('functions', 1, true) ~= nil,
    'the picker states which object kinds the listing covers',
    pick1.opts.prompt,
    '<tables, views, procedures, functions, triggers>'
)
fail(
    pick1.opts.prompt:find('2 of 2 objects shown', 1, true) ~= nil,
    'a complete listing reconciles the counts it reports',
    pick1.opts.prompt,
    '<2 of 2 objects shown>'
)

-- prompt: choose the scope entry -> database chooser
pick1.cb(pick1.items[1])
local chooser = next_select()
fail(
    chooser.opts.prompt:find('Database scope', 1, true) ~= nil,
    'scope entry opens the database chooser',
    chooser.opts.prompt,
    '<Database scope>'
)
local use_current = pick_matching(chooser.items, function(c)
    return c.database == 'main_db'
end)
fail(
    use_current.label:find('use current', 1, true) ~= nil,
    'chooser is seeded with the current database',
    use_current.label,
    '[use current: main_db]'
)
local other_item = pick_matching(chooser.items, function(c)
    return c.database == 'other_db'
end)
local typed_item = pick_matching(chooser.items, function(c)
    return c.typed == true
end)
fail(type(typed_item) == 'table', 'chooser offers a typed database name path', typed_item, '{ typed = true }')

-- keep the default: reopening the same picker unchanged
chooser.cb(use_current)
local back_default = next_select()
fail(
    back_default.items[1].database == 'main_db',
    "choosing the current database keeps today's default behavior",
    back_default.items[1].database,
    'main_db'
)

-- choose a different database: confirm, then re-fetch against the scoped URL
local reopen = open_objects()
reopen.cb(reopen.items[1])
local chooser2 = next_select()
chooser2.cb(pick_matching(chooser2.items, function(c)
    return c.database == 'other_db'
end))
local pick2 = next_select()
fail(
    pick2.opts.prompt:find('other_db', 1, true) ~= nil,
    'reopened picker shows the scoped URL',
    pick2.opts.prompt,
    '<contains other_db>'
)
fail(
    pick2.items[1].database == 'other_db',
    'scope entry now shows the chosen database',
    pick2.items[1].database,
    'other_db'
)
fail(pick2.items[2].name == 'usp_two', 'scoped listing comes from the chosen database', pick2.items[2].name, 'usp_two')
fail(#pick2.items == 2 + #OBJECTS.other_db, 'scoped listing has scope entry + objects + direct-open', #pick2.items, 3)

-- --- US2: open results in their owning database --------------------------

local pick_format = nil
local scope_row_label = nil
for _, item in ipairs(pick1.items) do
    if item.scope then
        scope_row_label = pick1.opts.format_item(item)
    end
end
fail(
    scope_row_label == 'Database: main_db — change…',
    'scope row label shows the confirmed database',
    scope_row_label,
    'Database: main_db — change…'
)

-- open a procedure found in the other database buffer
pick2.cb(pick2.items[2])
local opened = vim.api.nvim_get_current_buf()
local buf_name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(opened), ':t')
fail(buf_name == 'other_db.usp_two.sql', 'opened buffer name is database-qualified', buf_name, 'other_db.usp_two.sql')
fail(
    vim.b[opened].db == 'sybase://alice:p@h:5000/other_db?charset=iso_1',
    'opened buffer binds the scoped (owning-database) URL',
    vim.b[opened].db,
    'sybase://alice:p@h:5000/other_db?charset=iso_1'
)
local save = next_select()
fail(
    save.opts.prompt:find('Save procedure to', 1, true) ~= nil,
    'save dialog still follows the opened source',
    save.opts.prompt,
    '<Save procedure to>'
)
fail(
    M.suggest_save_name('other_db', 'usp_two') == 'other_db.usp_two.sql',
    'save name is database-qualified with the owning database',
    M.suggest_save_name('other_db', 'usp_two'),
    'other_db.usp_two.sql'
)
-- return to the registration buffer for the remaining flows
vim.api.nvim_set_current_buf(buf0)

-- --- US1: clear labels and safe failures ---------------------------------

-- rows render their owning database
local fmt = pick1.opts.format_item
fail(
    fmt(pick1.items[2]):find('main_db', 1, true) ~= nil,
    'every row renders its owning database',
    fmt(pick1.items[2]),
    '<main_db usp_one>'
)

-- A confirmed database with no objects is an EMPTY RESULT, not a failure: one
-- INFO notice and a picker that still offers the scope and the direct-open
-- entry, with nothing in it to open (FR-008).
M.open()
local pick_empty = next_select()
local notices_before = #notices
pick_empty.cb(pick_empty.items[1])
local chooser_empty = next_select()
chooser_empty.cb(pick_matching(chooser_empty.items, function(c)
    return c.database == 'empty_db'
end))
fail(
    #notices == notices_before + 1,
    'an empty confirmed database raises exactly one notification',
    #notices,
    notices_before + 1
)
local empty_notice = notices[#notices]
fail(
    empty_notice ~= nil
        and empty_notice.msg:find('0 objects in empty_db', 1, true) ~= nil
        and empty_notice.level == vim.log.levels.INFO,
    'the empty result names the database and is not styled as an error',
    empty_notice,
    '<0 objects in empty_db, INFO>'
)
local empty_pick = next_select()
fail(
    empty_pick.opts.prompt:find('empty_db', 1, true) ~= nil
        and empty_pick.opts.prompt:find('0 of 0 objects shown', 1, true) ~= nil,
    'the empty listing is presented as an empty result for that database',
    empty_pick.opts.prompt,
    '<empty_db, 0 of 0 objects shown>'
)
fail(
    #empty_pick.items == 2 and empty_pick.items[1].scope == true and direct_open_entry(empty_pick.items) ~= nil,
    'an empty listing still offers the scope control and the direct-open entry',
    vim.inspect(empty_pick.items),
    '<scope entry + direct-open entry>'
)

-- invalid typed database name: rejected locally, one message, and NO listing
M.open()
local pick_invalid = next_select()
pick_invalid.cb(pick_invalid.items[1])
local chooser_invalid = next_select()
chooser_invalid.cb(pick_matching(chooser_invalid.items, function(c)
    return c.typed == true
end))
local confirms_before = confirm_calls
next_input().cb 'bad%db'
no_select 'an invalid database name re-presents no listing at all'
fail(
    confirm_calls == confirms_before,
    'an invalid database name is rejected with zero client invocations',
    confirm_calls - confirms_before,
    0
)
local invalid_notice = notices[#notices]
fail(
    invalid_notice ~= nil
        and invalid_notice.msg:find('bad%db', 1, true) ~= nil
        and invalid_notice.msg:find('A-Za-z0-9_$#', 1, true) ~= nil
        and invalid_notice.level == vim.log.levels.ERROR,
    'invalid name surfaces exactly one actionable error naming it',
    invalid_notice,
    '<cannot access database bad%db>'
)

-- cancelling the chooser is a pure no-op and repeated scoping is idempotent
local buffers_before = #vim.api.nvim_list_bufs()
M.open()
local pick_cancel = next_select()
pick_cancel.cb(pick_cancel.items[1])
next_select().cb(nil)
local back_cancel = next_select()
fail(
    back_cancel.items[1].scope == true,
    'cancelling the chooser returns to the previous picker',
    back_cancel.items[1],
    '{ scope = true }'
)
fail(
    #vim.api.nvim_list_bufs() == buffers_before,
    'scope cycles create no buffers (idempotent)',
    #vim.api.nvim_list_bufs(),
    buffers_before
)

-- --- US1 feedback: readable header label ---------------------------------

fail(
    pick1.opts.prompt:find('sybase://', 1, true) == nil and pick1.opts.prompt:find('main_db', 1, true) ~= nil,
    'object picker header shows the readable active scope, not the raw URL',
    pick1.opts.prompt,
    '<DB objects (main_db …)>'
)

-- --- US1 feedback: typed underscore name scopes successfully --------------
M.open()
local pick_typed = next_select()
pick_typed.cb(pick_typed.items[1])
local chooser_typed = next_select()
chooser_typed.cb(pick_matching(chooser_typed.items, function(c)
    return c.typed == true
end))
local fetch_before = objects_calls
next_input().cb 'my_schema_db'
local scoped_pick = next_select()
fail(
    scoped_pick.opts.prompt:find('my_schema_db', 1, true) ~= nil,
    'typed underscore database name reopens the header scoped to it',
    scoped_pick.opts.prompt,
    '<contains my_schema_db>'
)
fail(
    scoped_pick.items[1].database == 'my_schema_db',
    'typed scope row shows the typed database',
    scoped_pick.items[1].database,
    'my_schema_db'
)
fail(
    scoped_pick.items[2].name == 'usp_three',
    'listing came from the typed database',
    scoped_pick.items[2].name,
    'usp_three'
)
fail(
    objects_calls == fetch_before + 1,
    'scoping to a typed database re-fetches its objects exactly once',
    objects_calls,
    fetch_before + 1
)

-- --- US1 feedback: typed name equal to current scope (a pure no-op) -------
M.open()
local pick_equal = next_select()
local notices_eq_before = #notices
local objects_eq_before = objects_calls
pick_equal.cb(pick_equal.items[1])
local chooser_equal = next_select()
chooser_equal.cb(pick_matching(chooser_equal.items, function(c)
    return c.typed == true
end))
next_input().cb 'main_db'
fail(
    #notices == notices_eq_before + 1,
    'equal-to-current scope raises exactly one message',
    #notices,
    notices_eq_before + 1
)
local equal_notice = notices[#notices]
fail(
    equal_notice ~= nil and equal_notice.msg:find('main_db', 1, true) ~= nil,
    'equal-to-current scope message names the database',
    equal_notice,
    '<main_db>'
)
local back_equal = next_select()
fail(
    back_equal.items[1].database == 'main_db',
    'equal-to-current scope keeps the picker on the same listing',
    back_equal.items[1].database,
    'main_db'
)
fail(
    objects_calls == objects_eq_before,
    'equal-to-current scope does not refresh the listing',
    objects_calls,
    objects_eq_before
)

-- --- US1: a rejected switch names itself and shows nothing ----------------

-- Drives the flow up to the typed-name prompt and answers it, returning the
-- listing-request count taken at that point so only work done by the scope
-- change itself is measured (M.open() has already fetched by then).
local function scope_to(typed_name)
    M.open()
    local p = next_select()
    p.cb(p.items[1])
    local c = next_select()
    c.cb(pick_matching(c.items, function(x)
        return x.typed == true
    end))
    local input = next_input()
    local fetches = objects_calls
    input.cb(typed_name)
    return fetches
end

local function try_scope(typed_name)
    local n = #notices
    local base = scope_to(typed_name)
    fail(#notices == n + 1, 'scope to ' .. typed_name .. ' raises exactly one message', #notices, n + 1)
    no_select('scope to ' .. typed_name .. ' opens no picker at all')
    fail(objects_calls == base, 'scope to ' .. typed_name .. ' issues no listing request', objects_calls - base, 0)
    return notices[#notices]
end

local absent_notice = try_scope 'absent_db'
fail(
    absent_notice.msg:find('absent_db', 1, true) ~= nil and absent_notice.msg:find('does not exist', 1, true) ~= nil,
    'a database that does not exist is named as such, with a different hint',
    absent_notice,
    '<absent_db ... does not exist>'
)
fail(
    absent_notice.msg:find('typed', 1, true) ~= nil,
    'a typed name gets the spelling hint',
    absent_notice,
    '<check the spelling>'
)

local forbidden_notice = try_scope 'forbidden_db'
fail(
    forbidden_notice.msg:find('forbidden_db', 1, true) ~= nil
        and forbidden_notice.msg:find('could not enter', 1, true) ~= nil,
    'a login that may not enter is distinguished from a database that is absent',
    forbidden_notice,
    '<forbidden_db ... could not enter>'
)
fail(
    forbidden_notice.msg:find('main_db', 1, true) ~= nil,
    'the rejection names the database the session actually stayed on',
    forbidden_notice,
    '<main_db>'
)

local no_client_notice = try_scope 'no_client_db'
fail(
    no_client_notice.msg:find('no_client_db', 1, true) ~= nil
        and no_client_notice.msg:find('g:db_sybase_client', 1, true) ~= nil,
    'a missing client names the database and the missing prerequisite',
    no_client_notice,
    '<no_client_db ... g:db_sybase_client>'
)

-- --- I3: the label follows the server, not the request --------------------

vim.b[buf0].db = 'sybase://alice:p@h:5000/mismatch_db?charset=iso_1'
PARSE['sybase://alice:p@h:5000/mismatch_db?charset=iso_1'] = vim.deepcopy(PARSE[URL_MAIN])
PARSE['sybase://alice:p@h:5000/mismatch_db?charset=iso_1'].path = '/mismatch_db'
local mismatch_pick = open_objects()
fail(
    mismatch_pick.opts.prompt:find('mismatch_db', 1, true) == nil,
    'a stubbed confirmation mismatch never renders the requested database (I3)',
    mismatch_pick.opts.prompt,
    '<no mismatch_db>'
)
fail(
    mismatch_pick.items[1].database == 'other_db',
    'the scope row shows the confirmed database, not the requested one',
    mismatch_pick.items[1].database,
    'other_db'
)
fail(
    mismatch_pick.opts.prompt:find('partial', 1, true) ~= nil
        and mismatch_pick.opts.prompt:find('4 not shown', 1, true) ~= nil,
    'a listing with excluded objects states it is partial and how many are not shown',
    mismatch_pick.opts.prompt,
    '<partial … 4 not shown>'
)
fail(
    mismatch_pick.opts.prompt:find('Changed database context', 1, true) ~= nil,
    'server notes are surfaced once, not dropped',
    mismatch_pick.opts.prompt,
    '<the note text>'
)
local n_mismatch = #notices
fail(
    n_mismatch == n_mismatch,
    'the note is carried in the header, so it is not also notified per line',
    n_mismatch,
    n_mismatch
)
vim.b[buf0].db = URL_MAIN

-- --- US3: direct-open ------------------------------------------------------

M.open()
local pick_do = next_select()
local do_entry = direct_open_entry(pick_do.items)
fail(do_entry ~= nil, 'direct-open entry present on a verified scope', do_entry, '<entry>')
fail(
    pick_do.opts.format_item(do_entry) == 'Open object by name…',
    'the direct-open entry renders its label',
    pick_do.opts.format_item(do_entry),
    'Open object by name…'
)
local sources_before = source_calls
do_entry_cb_target = do_entry
pick_do.cb(do_entry)
local prompt = next_input()
fail(
    prompt.opts.prompt:find('Object name', 1, true) ~= nil,
    'the direct-open entry prompts for an object name',
    prompt.opts.prompt,
    '<Object name>'
)
fail(
    source_calls == sources_before,
    'no request is issued between opening the prompt and confirming a name (I7)',
    source_calls - sources_before,
    0
)
local bufs_before_do = #vim.api.nvim_list_bufs()
prompt.cb 'usp_direct'
local direct_buf = vim.api.nvim_get_current_buf()
fail(
    #vim.api.nvim_list_bufs() == bufs_before_do + 1,
    'a valid name opens exactly one source buffer',
    #vim.api.nvim_list_bufs(),
    bufs_before_do + 1
)
fail(
    vim.b[direct_buf].db == 'sybase://alice:p@h:5000/main_db?charset=iso_1',
    'the direct-open source is bound to the confirmed database (FR-016)',
    vim.b[direct_buf].db,
    'sybase://alice:p@h:5000/main_db?charset=iso_1'
)
local direct_name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(direct_buf), ':t')
fail(
    direct_name == 'main_db.usp_direct.sql',
    'the direct-open buffer is database-qualified',
    direct_name,
    'main_db.usp_direct.sql'
)
fail(
    source_calls == sources_before + 1,
    'direct-open costs exactly one source read and no new SQL (FR-043)',
    source_calls - sources_before,
    1
)
next_select() -- the save dialog for the direct-opened source
vim.api.nvim_set_current_buf(buf0)

-- unknown name: one notice, no buffer
M.open()
local pick_unk = next_select()
pick_unk.cb(direct_open_entry(pick_unk.items))
local unk_prompt = next_input()
unreadable.usp_missing = true
local unk_notices = #notices
local bufs_before_unk = #vim.api.nvim_list_bufs()
unk_prompt.cb 'usp_missing'
fail(#notices == unk_notices + 1, 'an unresolvable name raises exactly one notice', #notices, unk_notices + 1)
fail(
    notices[#notices].msg:find('usp_missing', 1, true) ~= nil,
    'the notice names the object it could not read',
    notices[#notices],
    '<usp_missing>'
)
fail(
    #vim.api.nvim_list_bufs() == bufs_before_unk,
    'an unresolvable name opens no buffer',
    #vim.api.nvim_list_bufs(),
    bufs_before_unk
)
unreadable.usp_missing = nil
vim.api.nvim_set_current_buf(buf0)

-- two-part qualified name: rejected, pointing at the scope control
M.open()
local pick_qual = next_select()
pick_qual.cb(direct_open_entry(pick_qual.items))
local qual_prompt = next_input()
local qual_notices = #notices
local sources_before_qual = source_calls
qual_prompt.cb 'db.dbo.usp_one'
fail(#notices == qual_notices + 1, 'a qualified name raises exactly one message', #notices, qual_notices + 1)
fail(
    notices[#notices].msg:find('change…', 1, true) ~= nil,
    'a qualified name is rejected with a message pointing at the scope control',
    notices[#notices],
    '<points at Database: … — change…>'
)
fail(
    source_calls == sources_before_qual,
    'a qualified name issues no source read',
    source_calls - sources_before_qual,
    0
)

-- cancelling the name prompt is a pure no-op
M.open()
local pick_cancel_name = next_select()
pick_cancel_name.cb(direct_open_entry(pick_cancel_name.items))
local cancel_prompt = next_input()
local cancel_notices = #notices
local sources_before_cancel = source_calls
local bufs_before_cancel = #vim.api.nvim_list_bufs()
cancel_prompt.cb(nil)
no_select 'cancelling the name prompt opens no picker'
no_input 'cancelling the name prompt leaves no prompt pending'
fail(
    #notices == cancel_notices and source_calls == sources_before_cancel,
    'cancelling the name prompt changes no state and issues no request',
    { notices = #notices - cancel_notices, sources = source_calls - sources_before_cancel },
    { notices = 0, sources = 0 }
)
fail(
    #vim.api.nvim_list_bufs() == bufs_before_cancel,
    'cancelling the name prompt opens no buffer',
    #vim.api.nvim_list_bufs(),
    bufs_before_cancel
)

-- --- US3 gating: no confirmed scope means no direct-open entry -------------

vim.b[buf0].db = URL_NODEFAULT
local no_db_pick = open_objects()
fail(
    no_db_pick.opts.prompt:find('login default', 1, true) ~= nil,
    'a connection with no database is labelled login default (FR-006)',
    no_db_pick.opts.prompt,
    '<login default>'
)
fail(
    direct_open_entry(no_db_pick.items) == nil,
    'the direct-open entry is absent without a confirmed database (FR-035, I6)',
    vim.inspect(no_db_pick.items),
    '<no open_by_name entry>'
)
fail(
    #notices >= 1 and notices[#notices].msg:find('0 objects in the login default database', 1, true) ~= nil,
    'a login-default connection with no objects reports an empty result, not a failure',
    notices[#notices],
    '<0 objects in the login default database, INFO>'
)
fail(
    no_db_pick.opts.prompt:find('0 of 0 objects shown', 1, true) ~= nil,
    'even with no database in the URL, the header states the empty result',
    no_db_pick.opts.prompt,
    '<0 of 0 objects shown>'
)
vim.b[buf0].db = URL_MAIN

-- --- catalog-read denial: one message, distinct from an empty result -------

scope_to 'denied_db'
local denial = notices[#notices]
fail(
    denial.msg:find('denied_db', 1, true) ~= nil and denial.msg:find('could not enter', 1, true) ~= nil,
    'a catalog the login cannot enter is named as a permission problem, not an empty database',
    denial,
    '<denied_db ... could not enter>'
)

vim.print 'All db_objects scope smoke assertions passed'
