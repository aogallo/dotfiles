-- Objects/source smoke test (quickstart automated check 7).
-- Asserts the argv built by db#adapter#sybase#objects()/source()/tables()/
-- complete_database() for parsed sybase://u:p@h:5000/db URLs, following the
-- same shape as the adapter argv smoke test (T015): pre-parsed URL dicts are
-- passed directly so no db#url#parse stub is needed.
--
-- In-process shim: PATH is prepended with temp `sqsh`/`isql` executables so the
-- adapter's executable() guard passes without a real client, and db#systemlist
-- is stubbed from a temp autoload/db.vim (E746 requires a matching autoload
-- script) to capture cmd + batch and return canned output.
-- Exits with code 1 via :cquit on any assertion failure.

local adapter = 'autoload/db/adapter/sybase.vim'

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

local files = vim.api.nvim_get_runtime_file(adapter, false)
if #files == 0 then
    vim.print('FAIL: adapter not found on runtimepath: ' .. adapter)
    vim.cmd 'cquit'
end
vim.cmd('source ' .. files[#files])

local base = vim.fn.tempname()
vim.fn.mkdir(base .. '/bin', 'p')
vim.fn.mkdir(base .. '/autoload', 'p')
for _, name in ipairs { 'sqsh', 'isql' } do
    vim.fn.writefile({ '#!/bin/sh', 'exit 0' }, base .. '/bin/' .. name)
    os.execute('chmod +x ' .. base .. '/bin/' .. name)
end
local old_path = vim.env.PATH
vim.env.PATH = base .. '/bin:' .. old_path

-- E746: an autoload-style function name can only be defined from a matching
-- autoload script. g:__db_objects_smoke holds canned output + argv capture.
-- NOTE: only whole-table vim.g assignments persist to Vimscript; nested Lua
-- writes (vim.g.t.f = v) do not, so set_canned() re-assigns the whole table.
vim.g.__db_objects_smoke = { canned = {}, captured = nil }
vim.fn.writefile({
    'function! db#systemlist(cmd, ...) abort',
    '  let s = g:__db_objects_smoke',
    "  let s.captured = {'cmd': a:cmd, 'lines': get(a:000, 0, [])}",
    "  let s.all = get(s, 'all', []) + [get(a:000, 0, [])]",
    '  return s.canned',
    'endfunction',
}, base .. '/autoload/db.vim')
vim.opt.rtp:prepend(base)

local function set_canned(lines)
    vim.g.__db_objects_smoke = { canned = lines, captured = nil, all = {} }
end
-- Every batch sent since the last set_canned() (db#systemlist stub keeps the
-- last one in .captured; source() sends two queries, so multi-query asserts
-- need the full list).
local function captured_batches()
    return vim.g.__db_objects_smoke.all or {}
end
local function batches_contain(line)
    for _, batch in ipairs(captured_batches()) do
        for _, l in ipairs(batch) do
            if l == line then
                return true
            end
        end
    end
    return false
end
local function captured_cmd()
    return vim.g.__db_objects_smoke.captured.cmd
end
local function captured_lines()
    return vim.g.__db_objects_smoke.captured.lines
end

local url = {
    scheme = 'sybase',
    user = 'u',
    password = 'p',
    host = 'h',
    port = '5000',
    path = '/db',
    params = {},
}

local objects = vim.fn['db#adapter#sybase#objects']
local source = vim.fn['db#adapter#sybase#source']
local tables = vim.fn['db#adapter#sybase#tables']
local complete_database = vim.fn['db#adapter#sybase#complete_database']

vim.g.db_sybase_client = 'sqsh'

local function row_named(list, name)
    for _, r in ipairs(list) do
        if r.name == name then
            return r
        end
    end
end

-- Issue #92 root cause: ASE stores sysobjects.type as char(2), so the listing
-- filter is ('U','V','P','SF','TR','XP') and the client renders each row as
-- DOBJ~<name>~<type> with the type still blank-padded to two characters.
set_canned {
    'DDB~db',
    'DOBJ~orders~U ',
    'DOBJ~v_user_total~V ',
    'DOBJ~usp_calc~P ',
    'DOBJ~fn_avg~SF',
    'DOBJ~trg_orders~TR',
    'DOBJ~x_custom~XP',
    'DCNT~6',
}
local listing = objects(url)
local rows = listing.rows
fail(
    #rows == 6,
    'objects parses all six covered kinds (char(2) types)',
    rows,
    { 'orders', 'v_user_total', 'usp_calc', 'fn_avg', 'trg_orders', 'x_custom' }
)
fail(
    rows[1].kind == 'table' and rows[1].name == 'orders' and rows[1].database == 'db',
    'objects kind table, stamped with the reported database',
    rows[1],
    { name = 'orders', kind = 'table', database = 'db' }
)
fail(row_named(rows, 'v_user_total').kind == 'view', 'objects kind view', row_named(rows, 'v_user_total'), 'view')
fail(
    row_named(rows, 'usp_calc').kind == 'procedure',
    'objects kind procedure',
    row_named(rows, 'usp_calc'),
    'procedure'
)
fail(
    row_named(rows, 'fn_avg').kind == 'function',
    'objects kind function (SF) — impossible before the char(2) fix',
    row_named(rows, 'fn_avg'),
    'function'
)
fail(
    row_named(rows, 'trg_orders').kind == 'trigger',
    'objects kind trigger (TR) — impossible before the char(2) fix',
    row_named(rows, 'trg_orders'),
    'trigger'
)
fail(
    row_named(rows, 'x_custom').kind == 'function',
    'objects kind function (XP) — X never matched XP before the fix',
    row_named(rows, 'x_custom'),
    'function'
)

-- T033: the query carries the two-character kinds and none of the single-letter
-- values that hid objects.
local listing_sql = ''
for _, batch in ipairs(captured_batches()) do
    for _, l in ipairs(batch) do
        if l:find('from sysobjects', 1, true) then
            listing_sql = l
        end
    end
end
fail(
    listing_sql:find("'SF'", 1, true) ~= nil
        and listing_sql:find("'TR'", 1, true) ~= nil
        and listing_sql:find("'XP'", 1, true) ~= nil,
    "listing query filters on 'SF', 'TR' and 'XP'",
    listing_sql,
    "<contains 'SF' 'TR' 'XP'>"
)
fail(
    listing_sql:find("'F'", 1, true) == nil and listing_sql:find("'X'", 1, true) == nil,
    "listing query drops the never-matching single-letter 'F' and 'X'",
    listing_sql,
    "<no 'F' nor 'X'>"
)

-- T031 / T032: the char(2) padding is trimmed, and an unmapped type is carried
-- through verbatim rather than dropped.
set_canned { 'DDB~db', 'DOBJ~padded_tbl~U', 'DOBJ~seq_ids~SQ', 'DCNT~2' }
local odd = objects(url)
fail(
    row_named(odd.rows, 'padded_tbl').kind == 'table',
    'a blank-padded char(2) type is trimmed and still a table',
    row_named(odd.rows, 'padded_tbl'),
    'table'
)
fail(
    row_named(odd.rows, 'seq_ids').kind == 'SQ',
    'an unmapped type is carried through verbatim, not dropped',
    row_named(odd.rows, 'seq_ids'),
    'SQ'
)

-- T034: nothing but a DOBJ~ row can become an object — client framing and the
-- client's own "Changed database context" line are recorded, never listed.
set_canned {
    'DDB~db',
    'name',
    '-----',
    'DOBJ~real_obj~P ',
    '(2 rows affected)',
    "Changed database context to 'db'.",
}
local framed = objects(url)
fail(
    #framed.rows == 1 and framed.rows[1].name == 'real_obj',
    'headings, separators, row trailers and the switch notice never become objects',
    framed.rows,
    { 'real_obj' }
)
local reasons = {}
for _, d in ipairs(framed.diagnostics) do
    reasons[d.reason or d.severity] = d.text
end
fail(
    reasons.no_marker ~= nil and reasons.no_marker:find('Changed database context', 1, true) ~= nil,
    "the client's switch notice is recorded as a dropped row, not silently dropped",
    framed.diagnostics,
    '<one no_marker record>'
)
fail(#framed.diagnostics == 4, 'every unparsed line is accounted for', #framed.diagnostics, 4)

-- T035 / T062: one invocation, reported from the count row, and the
-- shown + excluded = reported invariant.
set_canned { 'DDB~db', 'DOBJ~a~U ', 'DOBJ~b~P ', 'DCNT~5' }
local partial = objects(url)
fail(#captured_batches() == 1, 'the whole listing costs one client invocation', #captured_batches(), 1)
fail(
    partial.reported == 5 and #partial.rows == 2 and partial.excluded == 3,
    'reported comes from the count row and shown + excluded = reported',
    { reported = partial.reported, shown = #partial.rows, excluded = partial.excluded },
    { reported = 5, shown = 2, excluded = 3 }
)
fail(
    (#partial.rows + partial.excluded) == partial.reported,
    'invariant I5: shown + excluded = reported',
    { #partial.rows, partial.excluded, partial.reported },
    { 2, 3, 5 }
)

-- T063: without the count row the listing cannot prove its own total.
set_canned { 'DDB~db', 'DOBJ~a~U ' }
local uncounted = objects(url)
fail(
    uncounted.reported == 0 and not uncounted.count_known,
    'a missing count row yields reported = 0 and an unprovable total',
    { reported = uncounted.reported, count_known = not not uncounted.count_known },
    { reported = 0, count_known = false }
)

-- T056 (adapter half): a server diagnostic survives parsing instead of being
-- filtered away; the picker asserts it is surfaced once.
set_canned { 'DDB~db', 'DOBJ~a~U ', 'Msg 2812, Level 16, State 62:', 'Could not find stored procedure.', 'DCNT~1' }
local with_msg = objects(url)
local errors = {}
for _, d in ipairs(with_msg.diagnostics) do
    if d.severity == 'error' then
        table.insert(errors, d.text)
    end
end
fail(
    #errors == 1 and errors[1]:find('Msg 2812', 1, true) ~= nil,
    'a server Msg line is captured as an error diagnostic, not discarded',
    with_msg.diagnostics,
    '<one error diagnostic>'
)
fail(#with_msg.rows == 1, 'a diagnostic beside a row does not become an object', #with_msg.rows, 1)

local want_obj_cmd_sqsh = { 'sqsh', '-S', 'h:5000', '-U', 'u', '-P', 'p', '-L', 'semicolon_hack=false', '-h' }
fail(vim.deep_equal(captured_cmd(), want_obj_cmd_sqsh), 'objects sqsh argv', captured_cmd(), want_obj_cmd_sqsh)
fail(
    captured_lines()[#captured_lines()] == '\\go',
    'objects sqsh batch uses \\go terminator',
    captured_lines()[#captured_lines()],
    '\\go'
)

-- --- confirm_database (issue #92, contract §1.1) -------------------------
-- A `use` that the server rejects leaves the session on the login default and
-- emits no error the old parser could see, so the confirmation compares
-- db_name() against the request instead of trusting the absence of a message.
local confirm_database = vim.fn['db#adapter#sybase#confirm_database']

set_canned { 'DDB~db' }
local ok_scope = confirm_database(url)
fail(
    ok_scope.result == 'confirmed' and ok_scope.confirmed == 'db' and ok_scope.requested == 'db',
    'confirm_database reports a match as confirmed',
    ok_scope,
    { requested = 'db', confirmed = 'db', result = 'confirmed' }
)

set_canned { 'DDB~master', 'DEX~0' }
local absent = confirm_database(url)
fail(
    absent.result == 'rejected_absent' and absent.confirmed == '' and absent.exists == 0,
    'confirm_database distinguishes a database that does not exist',
    absent,
    { confirmed = '', result = 'rejected_absent', exists = 0 }
)

set_canned { 'DDB~master', 'DEX~1' }
local forbidden = confirm_database(url)
fail(
    forbidden.result == 'rejected_forbidden' and forbidden.exists == 1,
    'confirm_database distinguishes a login that may not enter it',
    forbidden,
    { result = 'rejected_forbidden', exists = 1 }
)

set_canned { 'DDB~DB' }
local cased = confirm_database(url)
fail(
    cased.result == 'confirmed' and cased.confirmed == 'DB',
    'the comparison is case-insensitive (ASE collation) and keeps the server spelling',
    cased,
    { confirmed = 'DB', result = 'confirmed' }
)

set_canned { 'DDB~master' }
local nourl = confirm_database { scheme = 'sybase', host = 'h', path = '/', params = {} }
fail(
    nourl.result == 'no_database' and nourl.confirmed == '' and nourl.requested == '',
    'a connection with no database is reported as no_database, never invented',
    nourl,
    { requested = '', confirmed = '', result = 'no_database' }
)

-- T018: the confirmation costs one invocation whatever the database holds.
set_canned { 'DDB~db', 'DEX~1' }
confirm_database(url)
fail(#captured_batches() == 1, 'confirmation costs exactly one client invocation (FR-042)', #captured_batches(), 1)
local many = { 'DDB~db', 'DEX~1' }
for i = 1, 3000 do
    table.insert(many, 'DOBJ~obj' .. i .. '~P ')
end
table.insert(many, 'DCNT~3000')
set_canned(many)
confirm_database(url)
fail(
    #captured_batches() == 1,
    'the same single invocation for a 3,000-object database as for a 3-row one',
    #captured_batches(),
    1
)
set_canned { 'DDB~db', 'DEX~1' }
confirm_database(url)
local confirm_batch = captured_lines()
fail(
    vim.tbl_contains(confirm_batch, "select 'DDB~' + db_name()"),
    'confirmation asks the server which database is in effect',
    confirm_batch,
    "select 'DDB~' + db_name()"
)
fail(
    vim.tbl_contains(
        confirm_batch,
        "select 'DEX~' + convert(char(2), count(*)) from master..sysdatabases where name = 'db'"
    ),
    'the existence probe shares the confirmation batch, not a second round trip',
    confirm_batch,
    '<contains the master..sysdatabases probe>'
)

-- Source extraction (issue #88): catalog mode is the default and reassembles
-- the 255-byte syscomments rows, so no banner/heading/count reaches the buffer
-- and no line is cut mid-token. Row shape under the client: every row is
-- suffixed with `~` + ' ' (its text ended on a real newline, so the marker
-- lands alone on the last output line) or `~+` (row cut mid-line, so the next
-- output line continues the same source line).
local catalog_sql =
    "select convert(varchar(255), text) + '~' + case when text like '%' + char(10) then ' ' else '+' end from syscomments where id = object_id('usp_calc') order by number, colid2, colid"
set_canned {
    'create procedure usp_calc as',
    '  select @var = substring(@dat~+',
    'o, @poscicion, 1)',
    'go',
    '~ ',
}
local text = source(url, 'usp_calc')
local want_source = { 'create procedure usp_calc as', '  select @var = substring(@dato, @poscicion, 1)', 'go' }
fail(
    vim.deep_equal(text, want_source),
    'source reassembles 255-byte syscomments chunks into whole lines',
    text,
    want_source
)
fail(
    vim.tbl_contains(captured_lines(), catalog_sql),
    'source reads syscomments ordered by number, colid2, colid',
    captured_lines(),
    catalog_sql
)
fail(
    batches_contain "select case when count(*) > 0 then 'HIDDEN' else 'OK' end from syscomments where id = object_id('usp_calc') and (status & 1 = 1 or version is not null)",
    'source checks hidden/encrypted text before reading it',
    captured_batches(),
    'hidden-text count query'
)

-- Client framing (column heading + separator) must never reach the buffer.
set_canned { 'text', '--------', 'create proc usp_x as', 'select 1', 'go', '~ ' }
fail(
    vim.deep_equal(source(url, 'usp_x'), { 'create proc usp_x as', 'select 1', 'go' }),
    'source strips column heading and separator rows',
    source(url, 'usp_x'),
    { 'create proc usp_x as', 'select 1', 'go' }
)

-- A row whose marker the client truncated away is still its own line.
set_canned { 'create proc usp_x as', 'go' }
fail(
    vim.deep_equal(source(url, 'usp_x'), { 'create proc usp_x as', 'go' }),
    'source keeps a truncated final row on its own line',
    source(url, 'usp_x'),
    { 'create proc usp_x as', 'go' }
)

-- Hidden text (sp_hidetext / encrypted): no buffer, one actionable notice.
set_canned { 'HIDDEN' }
fail(
    vim.tbl_isempty(source(url, 'usp_hidden')),
    'source returns nothing for hidden/encrypted text',
    source(url, 'usp_hidden'),
    {}
)

-- Server error in the middle of the output is not source text.
set_canned { 'create proc usp_x as~', 'Msg 2812, Level 16, State 62:', 'Procedure not found.' }
fail(
    vim.tbl_isempty(source(url, 'usp_x')),
    'source returns nothing when the server reports an error',
    source(url, 'usp_x'),
    {}
)

-- Opt-in showsql mode (ASE 15.0.2+): the sp_helptext '# Lines of Text' block
-- is gone because sp_helptext delegates to sp_showtext.
vim.g.db_sybase_source_mode = 'showsql'
set_canned {
    '# Lines of Text',
    '---------------',
    '3',
    'text',
    '-------',
    'create procedure usp_calc as',
    'as',
    'select 1',
}
fail(
    vim.deep_equal(source(url, 'usp_calc'), { 'create procedure usp_calc as', 'as', 'select 1' }),
    'showsql mode strips the # Lines of Text block and headings',
    source(url, 'usp_calc'),
    { 'create procedure usp_calc as', 'as', 'select 1' }
)
fail(
    vim.tbl_contains(captured_lines(), "exec sp_helptext 'usp_calc', NULL, NULL, 'showsql,noparams'"),
    'showsql mode calls sp_helptext with showsql,noparams',
    captured_lines(),
    "exec sp_helptext 'usp_calc', NULL, NULL, 'showsql,noparams'"
)
vim.g.db_sybase_source_mode = nil

set_canned { "create proc it''s as", '~ ' }
source(url, "it's")
fail(
    batches_contain "select convert(varchar(255), text) + '~' + case when text like '%' + char(10) then ' ' else '+' end from syscomments where id = object_id('it''s') order by number, colid2, colid",
    'source escapes single quotes',
    captured_batches(),
    "contains object_id('it''s')"
)

set_canned { 'customers', 'orders', 'Msg 2812, Level 16' }
local want_tables = { 'customers', 'orders' }
fail(vim.deep_equal(tables(url), want_tables), 'tables parses single-token names', tables(url), want_tables)
fail(
    captured_lines()[#captured_lines() - 1] == "select name from sysobjects where type in ('U','V') order by name",
    'tables uses sysobjects U/V query',
    captured_lines()[#captured_lines() - 1],
    "select name from sysobjects where type in ('U','V') order by name"
)

set_canned { 'master', 'model', 'sybsystemdb', 'tempdb' }
local dbs = complete_database(url)
fail(
    vim.deep_equal(dbs, { 'master', 'model', 'sybsystemdb', 'tempdb' }),
    'complete_database lists databases',
    dbs,
    { 'master', 'model', 'sybsystemdb', 'tempdb' }
)
fail(not vim.tbl_contains(captured_cmd(), '-D'), 'complete_database connects without -D', captured_cmd(), 'no -D')

vim.g.db_sybase_client = 'isql'
set_canned { 'DDB~db', 'DOBJ~orders~U ', 'DCNT~1' }
objects(url)
local want_obj_cmd_isql = { 'isql', '-S', 'h:5000', '-U', 'u', '-P', 'p', '-n', '-w', '32000', '-b' }
fail(vim.deep_equal(captured_cmd(), want_obj_cmd_isql), 'objects isql argv', captured_cmd(), want_obj_cmd_isql)
fail(
    captured_lines()[#captured_lines()] == 'go',
    'objects isql batch uses go terminator',
    captured_lines()[#captured_lines()],
    'go'
)

vim.g.db_sybase_client = 'definitely-missing-db-client'
set_canned { 'nope' }
local missing = tables(url)
fail(vim.tbl_isempty(missing), 'tables returns [] for missing client', missing, {})
fail(
    vim.g.__db_objects_smoke.captured == nil,
    'missing client never spawns a job',
    vim.g.__db_objects_smoke.captured,
    nil
)
fail(vim.tbl_isempty(source(url, 'usp_calc')), 'source returns [] for missing client', source(url, 'usp_calc'), {})

-- A missing client is a value, not an exception, so the caller reports the
-- missing prerequisite exactly once instead of raising inside the adapter.
local no_client = confirm_database(url)
fail(
    no_client.result == 'not_attempted' and no_client.confirmed == '',
    'confirm_database returns a value for a missing client, never raises',
    no_client,
    { confirmed = '', result = 'not_attempted' }
)
fail(
    vim.tbl_isempty(objects(url).rows),
    'objects returns an empty listing for a missing client',
    objects(url),
    { rows = {} }
)
fail(
    vim.g.__db_objects_smoke.captured == nil,
    'a missing client still never spawns a job for objects/confirm',
    vim.g.__db_objects_smoke.captured,
    nil
)

vim.g.db_sybase_client = nil
vim.g.__db_objects_smoke = nil
vim.env.PATH = old_path
vim.opt.rtp:remove(base)
vim.fn.delete(base, 'rf')
vim.print 'All objects/source smoke assertions passed'
