-- Database context smoke test (specs/009-trim-trailing-whitespace, quickstart
-- automated check). Asserts the single answer to "which database is this
-- buffer talking to", the module the status line and the query path now share
-- (FR-016, FR-018, FR-025):
--   - url_database() agrees with the Sybase adapter's own s:database() for
--     every URL shape, so the label can never name a different database than
--     the rows come from
--   - url_from_buffer() accepts both b:db forms and neither leaks credentials
--   - database() is the buffer-level composition of the two
-- Exits with code 1 via :cquit on any assertion failure.

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

local db_context = require 'config.db_context'

--- agreement with the adapter ----------------------------------------------

-- db#adapter#sybase#s:database() is script-local, so the rule is reproduced
-- here from the same two lines it uses: db#url#parse() for the path, then
-- "empty unless there is something after the slash". If either side changes,
-- this check fails instead of the label quietly naming another database.
local function adapter_database(url)
    local path = vim.fn['db#url#parse'](url).path or ''
    return path:match '^/=*$' and '' or path:gsub('^/', '')
end

local urls = {
    'sybase://sa:pw@ase-host:5000/ventas',
    'sybase://sa:pw@ase-host/ventas',
    'sybase://sa:pw@ase-host:5000/ventas?charset=utf8',
    'sybase://sa@ase-host:5000/base-a',
    'sybase://sa:pw@ase-host:5000/master',
    'sybase://sa:pw@ase-host:5000/tmp$db',
}
for _, url in ipairs(urls) do
    local want = adapter_database(url)
    local got = db_context.url_database(url)
    fail(
        got == want and got ~= nil,
        'url_database agrees with the adapter for ' .. url:gsub(':[^@]*@', ':***@'),
        got,
        want
    )
end

-- '#' starts the fragment, so the database ends there. Reading past it would
-- name a database the connection never selects: the label would disagree with
-- the rows, which is the one thing this module exists to prevent.
fail(
    db_context.url_database 'sybase://sa:pw@ase:5000/tmp$#db' == 'tmp$',
    'a # ends the database, matching the URL parser',
    db_context.url_database 'sybase://sa:pw@ase:5000/tmp$#db',
    'tmp$'
)
fail(
    db_context.url_database 'sybase://sa:pw@ase:5000/ventas?charset=utf8' == 'ventas',
    'a ? ends the database, matching the URL parser',
    db_context.url_database 'sybase://sa:pw@ase:5000/ventas?charset=utf8',
    'ventas'
)

-- Paths the adapter cannot produce a database for: no path, empty path, and
-- non-Sybase schemes.
fail(
    db_context.url_database 'sybase://sa:pw@ase-host:5000' == nil,
    'no path means no database',
    db_context.url_database 'sybase://sa:pw@ase-host:5000',
    nil
)
fail(
    db_context.url_database 'sybase://sa:pw@ase-host:5000/' == nil,
    'empty path means no database',
    db_context.url_database 'sybase://sa:pw@ase-host:5000/',
    nil
)
fail(
    db_context.url_database 'postgres://u:p@h:5432/ventas' == nil,
    'non-Sybase URL means no database',
    db_context.url_database 'postgres://u:p@h:5432/ventas',
    nil
)
fail(
    db_context.url_database 'not a url' == nil,
    'unparsable URL means no database',
    db_context.url_database 'not a url',
    nil
)

--- scheme predicate ---------------------------------------------------------

fail(db_context.is_sybase 'sybase://a@b/c' == true, 'is_sybase accepts a Sybase URL', true, true)
fail(db_context.is_sybase 'postgres://a@b/c' == false, 'is_sybase rejects other schemes', false, false)
fail(db_context.is_sybase 'sybase:/oops' == false, 'is_sybase rejects a single slash', false, false)

--- buffer context -----------------------------------------------------------

local function bound(value)
    local buf = vim.api.nvim_create_buf(true, false)
    vim.b[buf].db = value
    return buf
end

fail(
    db_context.url_from_buffer(bound 'sybase://sa:pw@ase:5000/ventas') == 'sybase://sa:pw@ase:5000/ventas',
    'string b:db form is read',
    db_context.url_from_buffer(bound 'sybase://sa:pw@ase:5000/ventas'),
    'sybase://sa:pw@ase:5000/ventas'
)
fail(
    db_context.url_from_buffer(bound { conn = 'sybase://sa:pw@ase:5000/ventas' }) == 'sybase://sa:pw@ase:5000/ventas',
    'table b:db form is read',
    db_context.url_from_buffer(bound { conn = 'sybase://sa:pw@ase:5000/ventas' }),
    'sybase://sa:pw@ase:5000/ventas'
)
fail(
    db_context.url_from_buffer(bound { db_url = 'sybase://sa:pw@ase:5000/base-a' }) == 'sybase://sa:pw@ase:5000/base-a',
    'legacy db_url b:db form is read',
    db_context.url_from_buffer(bound { db_url = 'sybase://sa:pw@ase:5000/base-a' }),
    'sybase://sa:pw@ase:5000/base-a'
)
fail(
    db_context.url_from_buffer(vim.api.nvim_create_buf(true, false)) == nil,
    'unbound buffer has no connection',
    'nil',
    'nil'
)
fail(db_context.url_from_buffer(bound(42)) == nil, 'unusable b:db value has no connection', 'nil', 'nil')
fail(db_context.url_from_buffer(bound {}) == nil, 'empty b:db table has no connection', 'nil', 'nil')

--- buffer-level database ----------------------------------------------------

fail(
    db_context.database(bound 'sybase://sa:pw@ase:5000/ventas') == 'ventas',
    'database reads the Sybase URL path',
    db_context.database(bound 'sybase://sa:pw@ase:5000/ventas'),
    'ventas'
)
fail(
    db_context.database(bound 'sybase://sa:pw@ase:5000') == nil,
    'a connection with no database path reports none',
    'nil',
    'nil'
)
fail(
    db_context.database(vim.api.nvim_create_buf(true, false)) == nil,
    'an unbound buffer reports no database',
    'nil',
    'nil'
)

-- The component renders only this name, so assert the credential-bearing URL
-- never appears in the answer.
fail(
    db_context.database(bound 'sybase://sa:hunter2@ase:5000/ventas') == 'ventas',
    'the database answer carries no credentials',
    db_context.database(bound 'sybase://sa:hunter2@ase:5000/ventas'),
    'ventas'
)

--- the text scan ------------------------------------------------------------

-- A scratch SQL buffer bound to a connection, and the text to put in it.
local CONNECTED = 'sybase://sa:pw@ase:5000/ventas'
local NO_DATABASE = 'sybase://sa:pw@ase:5000'

-- `url` defaults to a connected buffer; NO_CONNECTION means a buffer with no
-- connection at all, which is a different case from a connection with no
-- database and gets its own answer.
local NO_CONNECTION = setmetatable({}, {
    __tostring = function()
        return 'NO_CONNECTION'
    end,
})

local function sql_buffer(lines, url)
    local buf = vim.api.nvim_create_buf(true, false)
    vim.bo[buf].filetype = 'sql'
    if url ~= NO_CONNECTION then
        vim.b[buf].db = url or CONNECTED
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    return buf
end

local function switched(lines)
    local switch = db_context.switches(sql_buffer(lines))
    return switch and switch.name or nil
end

fail(
    switched { 'use base-a', 'select 1' } == 'base-a',
    'a use statement is detected',
    switched { 'use base-a', 'select 1' },
    'base-a'
)
fail(
    switched { '  USE   base-a  ' } == 'base-a',
    'a lower/upper/spaced use is the same statement',
    switched { '  USE   base-a  ' },
    'base-a'
)
fail(switched { 'use a', 'use b', 'use c' } == 'c', 'the last use wins', switched { 'use a', 'use b', 'use c' }, 'c')
fail(
    switched { 'select * from base-a..t2' } == 'base-a..t2',
    'a two-part name is detected',
    switched { 'select * from base-a..t2' },
    'base-a..t2'
)
fail(
    switched { 'select * from base-b .. t2' } == 'base-b..t2',
    'a two-part name may be spaced',
    switched { 'select * from base-b .. t2' },
    'base-b..t2'
)
fail(
    switched { 'select * from tmp$db..#t' } == 'tmp$db..#t',
    '$ and # survive in names',
    switched { 'select * from tmp$db..#t' },
    'tmp$db..#t'
)
fail(
    switched { 'use base-a', 'select 1', 'use base-b' } == 'base-b',
    'a use after a two-part name still wins',
    switched { 'use base-a', 'select 1', 'use base-b' },
    'base-b'
)
fail(
    switched { 'select * from a..b', 'select * from c..d' } == 'a..b',
    'without a use, the first two-part name is reported',
    switched { 'select * from a..b', 'select * from c..d' },
    'a..b'
)

-- Things that look like switches but are not statements.
fail(
    switched { '-- use base-a', 'select 1' } == nil,
    'a use inside a line comment is ignored',
    switched { '-- use base-a', 'select 1' },
    'nil'
)
fail(
    switched { 'select 1 -- trailing use base-a' } == nil,
    'a use after a comment marker is ignored',
    switched { 'select 1 -- trailing use base-a' },
    'nil'
)
fail(
    switched { '/* use base-a */', 'select 1' } == nil,
    'a use inside a one-line block comment is ignored',
    switched { '/* use base-a */', 'select 1' },
    'nil'
)
fail(
    switched { '/*', 'use base-a', '*/', 'select 1' } == nil,
    'a use inside a multi-line block comment is ignored',
    switched { '/*', 'use base-a', '*/', 'select 1' },
    'nil'
)
fail(
    switched { '/* never closed', 'use base-a' } == nil,
    'an unterminated block comment keeps the rest ignored',
    switched { '/* never closed', 'use base-a' },
    'nil'
)
fail(
    switched { "select 'use base-a' from t" } == nil,
    'a use inside a string literal is ignored',
    switched { "select 'use base-a' from t" },
    'nil'
)
fail(
    switched { "select 'x' , 'a..b'" } == nil,
    'a two-part name inside a string is ignored',
    switched { "select 'x' , 'a..b'" },
    'nil'
)
fail(
    switched { 'select * from dbo.t' } == nil,
    'a single-dot schema name is not a database switch',
    switched { 'select * from dbo.t' },
    'nil'
)
fail(
    switched { 'select * from #temp' } == nil,
    'a temp table is not a switch',
    switched { 'select * from #temp' },
    'nil'
)
fail(
    switched { 'update used = 1' } == nil,
    'a column starting with use is not a use statement',
    switched { 'update used = 1' },
    'nil'
)
fail(switched { 'select 1' } == nil, 'ordinary SQL reports no switch', switched { 'select 1' }, 'nil')

--- the label ----------------------------------------------------------------

fail(
    db_context.label(sql_buffer { 'select 1' }) == 'DB ventas',
    'a clean SQL buffer shows the connection database',
    db_context.label(sql_buffer { 'select 1' }),
    'DB ventas'
)
fail(
    db_context.label(sql_buffer { 'use base-a' }) == 'DB ventas ⚠ base-a',
    'a conflicting buffer shows the mark beside the database',
    db_context.label(sql_buffer { 'use base-a' }),
    'DB ventas ⚠ base-a'
)
fail(
    db_context.label(sql_buffer { 'select * from base-b..t2' }) == 'DB ventas ⚠ base-b..t2',
    'a two-part conflict names the switch',
    db_context.label(sql_buffer { 'select * from base-b..t2' }),
    'DB ventas ⚠ base-b..t2'
)
fail(
    db_context.label(sql_buffer({ 'select 1' }, NO_DATABASE)) == 'DB —',
    'a connection with no database shows the marker',
    db_context.label(sql_buffer({ 'select 1' }, NO_DATABASE)),
    'DB —'
)
fail(
    db_context.label(sql_buffer({ 'select 1' }, NO_CONNECTION)) == 'DB —',
    'a SQL buffer with no connection shows the marker',
    db_context.label(sql_buffer({ 'select 1' }, NO_CONNECTION)),
    'DB —'
)

-- Excluded by filetype, not by buffer name (contract §4).
local other_ft = sql_buffer { 'use base-a' }
vim.bo[other_ft].filetype = 'sh'
fail(db_context.label(other_ft) == '', 'a non-SQL filetype renders nothing', db_context.label(other_ft), "''")
fail(not db_context.conflict(other_ft), 'a non-SQL filetype reports no conflict', db_context.conflict(other_ft), false)

local drawer = sql_buffer { 'use base-a' }
vim.bo[drawer].filetype = 'dbui'
fail(db_context.label(drawer) == '', 'the object drawer renders nothing', db_context.label(drawer), "''")
-- The other DB buffers the editor opens are `dbui` (the drawer, see
-- db_jump.lua) and `n` (the connection list, see db_connections.lua). A result
-- window is a `pedit` on the output file, so it is covered by the same rule.
local connections = sql_buffer { 'use base-a' }
vim.bo[connections].filetype = 'n'
fail(db_context.label(connections) == '', 'the connection list renders nothing', db_context.label(connections), "''")

fail(
    db_context.conflict(sql_buffer { 'select 1' }) == false,
    'a clean buffer reports no conflict',
    db_context.conflict(sql_buffer { 'select 1' }),
    false
)
fail(
    db_context.conflict(sql_buffer { 'use base-a' }) == true,
    'a conflicting buffer reports a conflict',
    db_context.conflict(sql_buffer { 'use base-a' }),
    true
)

--- the pre-execution message ------------------------------------------------

local function switched_message(lines, url)
    return db_context.switch_message(sql_buffer(lines, url))
end

fail(
    switched_message { 'use base-a', 'select 1' }
        == 'DB query runs on "ventas", but the text switches to "base-a". Check the statement before executing.',
    'the message names both databases and nothing else',
    switched_message { 'use base-a', 'select 1' },
    'DB query runs on "ventas", but the text switches to "base-a". Check the statement before executing.'
)
fail(switched_message { 'select 1' } == nil, 'no message without a switch', switched_message { 'select 1' }, 'nil')
fail(
    switched_message({ 'use base-a' }, NO_DATABASE) == nil,
    'no message when the connection declares no database',
    switched_message({ 'use base-a' }, NO_DATABASE),
    'nil'
)

--- nothing leaks the connection (contract §2 rule 5, §3 rule 3) -------------

local secret_url = 'sybase://sa:hunter2@ase-host:5000/ventas'
local leaking = {
    db_context.label(sql_buffer { 'use base-a' }, secret_url),
    db_context.switch_message(sql_buffer { 'use base-a' }, secret_url),
}
for i, rendered in ipairs(leaking) do
    fail(
        rendered ~= nil
            and not rendered:find('hunter2', 1, true)
            and not rendered:find('ase-host', 1, true)
            and not rendered:find('sybase://', 1, true)
            and not rendered:find('@', 1, true),
        'rendered output ' .. i .. ' carries no host, user, or password',
        rendered,
        'database names only'
    )
end

--- the pre-execution listener ----------------------------------------------

-- A sink, not a call-through: see no_formatter_warning_smoke.lua for why the
-- configuration's self-healing notify wrapper must never capture a function
-- that calls back into it.
local warnings = {}
local real_notify = vim.notify
vim.notify = function(msg, level)
    warnings[#warnings + 1] = { message = tostring(msg), level = level }
end

db_context.setup()
db_context.setup()

local function execute(buf)
    warnings = {}
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_exec_autocmds('User', { pattern = '*/DBExecutePre', modeline = false })
    return warnings
end

local conflicting = sql_buffer { 'use base-a', 'select 1' }
local conflict_lines = vim.api.nvim_buf_get_lines(conflicting, 0, -1, false)
local conflict_warnings = execute(conflicting)
fail(#conflict_warnings == 1, 'a conflicting buffer warns exactly once', #conflict_warnings, 1)
fail(
    conflict_warnings[1]
        and conflict_warnings[1].message:find('ventas', 1, true) ~= nil
        and conflict_warnings[1].message:find('base-a', 1, true) ~= nil,
    'the warning names both databases',
    conflict_warnings[1] and conflict_warnings[1].message,
    'mentions ventas and base-a'
)
fail(
    conflict_warnings[1] and conflict_warnings[1].level == vim.log.levels.WARN,
    'the warning is a warning, never an error',
    conflict_warnings[1] and conflict_warnings[1].level,
    vim.log.levels.WARN
)
fail(
    vim.deep_equal(vim.api.nvim_buf_get_lines(conflicting, 0, -1, false), conflict_lines),
    'the buffer is unchanged after the warning, so the query runs as written (FR-020)',
    vim.api.nvim_buf_get_lines(conflicting, 0, -1, false),
    conflict_lines
)

fail(#execute(sql_buffer { 'select 1' }) == 0, 'a clean buffer warns not at all', #warnings, 0)
fail(
    #execute(sql_buffer({ 'use base-a' }, NO_DATABASE)) == 0,
    'a buffer with no database warns not at all',
    #warnings,
    0
)
local non_sql = sql_buffer { 'use base-a' }
vim.bo[non_sql].filetype = 'sh'
fail(#execute(non_sql) == 0, 'a non-SQL buffer warns not at all', #warnings, 0)

vim.notify = real_notify
vim.print 'All database context smoke assertions passed'
