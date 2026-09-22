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
    '  return s.canned',
    'endfunction',
}, base .. '/autoload/db.vim')
vim.opt.rtp:prepend(base)

local function set_canned(lines)
    vim.g.__db_objects_smoke = { canned = lines, captured = nil }
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

set_canned { 'create procedure usp_calc as', '  select 1', '', 'go' }
local text = source(url, 'usp_calc')
fail(
    vim.deep_equal(text, { 'create procedure usp_calc as', '  select 1', '', 'go' }),
    'source returns full lines unchanged',
    text,
    { 'create procedure usp_calc as', '  select 1', '', 'go' }
)
fail(
    captured_lines()[#captured_lines() - 1] == "exec sp_helptext 'usp_calc'",
    'source builds sp_helptext call',
    captured_lines()[#captured_lines() - 1],
    "exec sp_helptext 'usp_calc'"
)
source(url, "it's")
fail(
    vim.tbl_contains(captured_lines(), "exec sp_helptext 'it''s'"),
    'source escapes single quotes',
    captured_lines(),
    "contains exec sp_helptext 'it''s'"
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
local want_obj_cmd_isql = { 'isql', '-S', 'h:5000', '-U', 'u', '-P', 'p', '-b' }
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
