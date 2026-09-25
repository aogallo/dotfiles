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

set_canned { 'orders          U', 'v_user_total    V', 'usp_calc        P', 'fn_avg          F', 'x_custom        X' }
local rows = objects(url)
fail(#rows == 5, 'objects parses all five kinds', rows, { 'orders', 'v_user_total', 'usp_calc', 'fn_avg', 'x_custom' })
fail(
    rows[1].kind == 'table' and rows[1].name == 'orders',
    'objects kind table',
    rows[1],
    { name = 'orders', kind = 'table' }
)
fail(rows[2].kind == 'view', 'objects kind view', rows[2], { name = 'v_user_total', kind = 'view' })
fail(rows[3].kind == 'procedure', 'objects kind procedure', rows[3], { name = 'usp_calc', kind = 'procedure' })
fail(rows[4].kind == 'function', 'objects kind function (F)', rows[4], { name = 'fn_avg', kind = 'function' })
fail(rows[5].kind == 'function', 'objects kind function (X)', rows[5], { name = 'x_custom', kind = 'function' })

local want_obj_cmd_sqsh = { 'sqsh', '-S', 'h:5000', '-U', 'u', '-P', 'p', '-L', 'semicolon_hack=false', '-h' }
fail(vim.deep_equal(captured_cmd(), want_obj_cmd_sqsh), 'objects sqsh argv', captured_cmd(), want_obj_cmd_sqsh)
fail(
    captured_lines()[#captured_lines()] == '\\go',
    'objects sqsh batch uses \\go terminator',
    captured_lines()[#captured_lines()],
    '\\go'
)

set_canned { 'Msg 2812, Level 16, State 62:', 'Procedure or function not found.' }
fail(vim.tbl_isempty(objects(url)), 'objects filters diagnostic lines', objects(url), {})

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
set_canned { 'orders          U' }
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

vim.g.db_sybase_client = nil
vim.g.__db_objects_smoke = nil
vim.env.PATH = old_path
vim.opt.rtp:remove(base)
vim.fn.delete(base, 'rf')
vim.print 'All objects/source smoke assertions passed'
