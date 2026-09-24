-- Database-scope smoke test (specs/005-database-scope, quickstart automated
-- check 3). Headless coverage of the object-search scope flow:
--   - contract: the REAL db#adapter#sybase#with_database() swaps the URL path
--     and preserves auth/host/port/params; invalid names (incl. '%') return ''
--   - flow: scope entry -> database chooser (complete_database, seeded with
--     the connected database) -> apply with_database -> re-fetch -> picker at
--     the chosen database (FR-001/FR-002)
--   - owning-database binding: opened buffers bind b:db to the scoped URL and
--     are named <database>.<object>.sql (FR-004/FR-005)
--   - labels/errors: rows render with their owning database (FR-003); empty
--     and invalid listings surface exactly one actionable message and no
--     picker/buffer (FR-007/FR-008); cancelling stays non-destructive and
--     repeated scoping is idempotent (FR-009)
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

local function next_input()
    if #input_calls == 0 then
        vim.print 'FAIL expected a vim.ui.input call (none pending)'
        vim.cmd 'cquit'
    end
    return table.remove(input_calls, 1)
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

-- --- adapter + ui stubs ------------------------------------------------

local URL_MAIN = 'sybase://alice:p@h:5000/main_db?charset=iso_1'

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
    empty_db = {},
}

vim.fn['db#adapter#sybase#objects'] = function(url)
    local db = url:match '^sybase://[^/]*/([^?]*)'
    return OBJECTS[db] or {}
end
vim.fn['db#adapter#sybase#complete_database'] = function()
    return { 'main_db', 'other_db', 'empty_db' }
end
vim.fn['db#adapter#sybase#source'] = function(_, name)
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

-- --- contract: with_database() (T006) ------------------------------------

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

-- --- US1: choose the database the search runs in -------------------------

local pick1 = open_objects()
fail(
    pick1.opts.prompt:find('main_db', 1, true) ~= nil,
    'object picker prompt shows the connected URL',
    pick1.opts.prompt,
    '<contains main_db>'
)
fail(pick1.items[1].scope == true, 'picker leads with the scope entry', pick1.items[1], '{ scope = true }')
fail(
    pick1.items[1].database == 'main_db',
    'scope entry shows the connected database',
    pick1.items[1].database,
    'main_db'
)
fail(
    #pick1.items == 1 + #OBJECTS.main_db,
    'default listing is the connected database (scope entry + objects)',
    #pick1.items,
    3
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

-- keep the default: reopening the same picker unchanged (FR-006/SC-005)
chooser.cb(use_current)
local back_default = next_select()
fail(
    back_default.items[1].database == 'main_db',
    "choosing the current database keeps today's default behavior",
    back_default.items[1].database,
    'main_db'
)

-- choose a different database: re-fetch against the scoped URL
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
fail(#pick2.items == 1 + #OBJECTS.other_db, 'scoped listing has scope entry + chosen database objects', #pick2.items, 2)

-- --- US2: open and execute results in their owning database --------------

local pick_format = nil
local scope_row_label = nil
for _, item in ipairs(pick1.items) do
    if item.scope then
        scope_row_label = pick1.opts.format_item(item)
    end
end
fail(
    scope_row_label == 'Database: main_db — change…',
    'scope row label shows the connected database',
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

-- --- US3: clear labels and safe failures ---------------------------------

-- rows render their owning database (FR-003)
local fmt = pick1.opts.format_item
fail(
    fmt(pick1.items[2]):find('main_db', 1, true) ~= nil,
    'every row renders its owning database',
    fmt(pick1.items[2]),
    '<main_db usp_one>'
)

-- empty scoped listing: one actionable message, no picker/buffer (FR-007)
M.open()
local pick_empty = next_select()
pick_empty.cb(pick_empty.items[1])
local chooser_empty = next_select()
chooser_empty.cb(pick_matching(chooser_empty.items, function(c)
    return c.database == 'empty_db'
end))
fail(#select_calls == 0, 'empty scoped listing opens no picker', #select_calls, 0)
local empty_notice = notices[#notices]
fail(
    empty_notice ~= nil
        and empty_notice.msg:find('no objects returned', 1, true) ~= nil
        and empty_notice.msg:find('empty_db', 1, true) ~= nil
        and empty_notice.level == vim.log.levels.ERROR,
    'empty listing surfaces exactly one actionable message naming the database',
    empty_notice,
    '<no objects returned ... empty_db>'
)

-- invalid typed database name: canonical error, flow stays alive (FR-007/FR-008)
M.open()
local pick_invalid = next_select()
pick_invalid.cb(pick_invalid.items[1])
local chooser_invalid = next_select()
chooser_invalid.cb(pick_matching(chooser_invalid.items, function(c)
    return c.typed == true
end))
next_input().cb 'bad%db'
local back_invalid = next_select()
fail(
    back_invalid.items[1].scope == true,
    'invalid database name returns to the previous picker (non-destructive)',
    back_invalid.items[1],
    '{ scope = true }'
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

-- cancelling the chooser is a pure no-op and repeated scoping is idempotent (FR-009)
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

vim.print 'All db_objects scope smoke assertions passed'
