-- Adapter argv smoke test (quickstart automated check 4).
-- Asserts the argv built by db#adapter#sybase#interactive()/input() for a parsed
-- sybase://u:p@h:5000/db URL, including the sqsh `go` -> `\go` transform.
-- A pre-parsed URL dict is passed directly (the adapter accepts the same shape
-- db#url#parse returns), so no db#url#parse stub is needed.
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

local url = {
    scheme = 'sybase',
    user = 'u',
    password = 'p',
    host = 'h',
    port = '5000',
    path = '/db',
    params = {},
}
local interactive = vim.fn['db#adapter#sybase#interactive']
local input = vim.fn['db#adapter#sybase#input']

local expect_default = vim.fn.has 'win32' == 1 and 'isql' or 'sqsh'
local got_default = interactive(url)
if got_default[1] == expect_default then
    vim.print('PASS default client is ' .. expect_default)
else
    vim.print('FAIL default client is ' .. got_default[1] .. ', expected ' .. expect_default)
    vim.cmd 'cquit'
end

vim.g.db_sybase_client = 'isql'
local isql_base = { 'isql', '-S', 'h:5000', '-U', 'u', '-P', 'p', '-n', '-w', '32000' }
local got_isql = interactive(url)
fail(vim.deep_equal(got_isql, isql_base), 'isql interactive argv (no -D, table flags)', got_isql, isql_base)

-- The registry convention is the registered server name WITHOUT a port (-S <name>
-- resolves the port from the client configuration). Lock that in.
local named_url = { scheme = 'sybase', user = 'u', password = 'p', host = 'dev', path = '/db', params = {} }
local got_named = interactive(named_url)
fail(
    vim.deep_equal(got_named, { 'isql', '-S', 'dev', '-U', 'u', '-P', 'p', '-n', '-w', '32000' }),
    'isql interactive argv honors server name without port',
    got_named,
    { 'isql', '-S', 'dev', '-U', 'u', '-P', 'p', '-n', '-w', '32000' }
)

local infile = vim.fn.tempname() .. '.sql'
local batch = { 'select 1', 'go', ' GO ', 'print 2', 'go' }
vim.fn.writefile(batch, infile)

local got_isql_input = input(url, infile)
local want_isql_prefix = { 'isql', '-S', 'h:5000', '-U', 'u', '-P', 'p', '-n', '-w', '32000', '-i' }
fail(
    vim.deep_equal(vim.list_slice(got_isql_input, 1, 11), want_isql_prefix),
    'isql input argv prefix (no -D, table flags)',
    got_isql_input,
    want_isql_prefix
)
local isql_copy = got_isql_input[#got_isql_input]
fail(
    vim.deep_equal(vim.fn.readfile(isql_copy), { 'use db', 'select 1', 'go', ' GO ', 'print 2', 'go' }),
    'isql input copy prepends use db',
    vim.fn.readfile(isql_copy),
    { 'use db', 'select 1', 'go', ' GO ', 'print 2', 'go' }
)
vim.fn.delete(isql_copy)

vim.g.db_sybase_client = 'sqsh'
local sqsh_base = { 'sqsh', '-S', 'h:5000', '-U', 'u', '-P', 'p', '-L', 'semicolon_hack=false' }
local got_sqsh = interactive(url)
fail(vim.deep_equal(got_sqsh, sqsh_base), 'sqsh interactive argv (no -D)', got_sqsh, sqsh_base)

local got_sqsh_input = input(url, infile)
local want_sqsh_prefix = { 'sqsh', '-S', 'h:5000', '-U', 'u', '-P', 'p', '-L', 'semicolon_hack=false', '-i' }
fail(
    vim.deep_equal(vim.list_slice(got_sqsh_input, 1, 10), want_sqsh_prefix),
    'sqsh input argv prefix',
    got_sqsh_input,
    want_sqsh_prefix
)

local copy = got_sqsh_input[#got_sqsh_input]
local copy_lines = vim.fn.readfile(copy)
fail(
    vim.deep_equal(copy_lines, { 'use db', 'select 1', '\\go', '\\go', 'print 2', '\\go' }),
    'sqsh input transformed copy (use db + go -> \\go)',
    copy_lines,
    { 'use db', 'select 1', '\\go', '\\go', 'print 2', '\\go' }
)
fail(
    vim.deep_equal(vim.fn.readfile(infile), batch),
    'sqsh input leaves original file untouched',
    vim.fn.readfile(infile),
    batch
)

-- A nonexistent input temp file (db#connect() probe path) must pass through
-- untouched so dadbod's executable() check can raise the actionable
-- missing-client error instead of an E484 inside the transform.
local missing_probe = vim.fn.tempname() .. '.nope.sql'
local got_probe = input(url, missing_probe)
local want_probe = { 'sqsh', '-S', 'h:5000', '-U', 'u', '-P', 'p', '-L', 'semicolon_hack=false', '-i', missing_probe }
fail(vim.deep_equal(got_probe, want_probe), 'sqsh input probe passes missing temp through', got_probe, want_probe)

-- A URL without a database must not emit any DB-selection lines (no -D, no use).
local no_db_url = { scheme = 'sybase', user = 'u', password = 'p', host = 'h', port = '5000', path = '/', params = {} }
local want_no_db = { 'sqsh', '-S', 'h:5000', '-U', 'u', '-P', 'p', '-L', 'semicolon_hack=false' }
local got_no_db = interactive(no_db_url)
fail(vim.deep_equal(got_no_db, want_no_db), 'no-db URL omits -D and use lines', got_no_db, want_no_db)

vim.fn.delete(copy)
vim.fn.delete(infile)

-- confirm_database(): the third outcome is selected by type(). exists is
-- polymorphic — the String '' while the probe is unreadable, a Number once a
-- marker sets it — and '' coerces to 0, so a numeric comparison would report an
-- unreadable probe as a database that does not exist (R-0006; specs/012).
local confirm = vim.fn['db#adapter#sybase#confirm_database']

-- s:run_query() spawns the real client, so the probe is injected by pointing the
-- client at a tiny executable that drains its input and prints the canned
-- response. That drives the real confirm_database() with no database. A Lua-side
-- vim.fn['db#systemlist'] stub would not be visible to Vimscript, and db#systemlist
-- is autoloaded (its name cannot be redefined from the command line).
local probe_file = vim.fn.tempname()
local fake_client = vim.fn.tempname() .. '.sh'

local function confirm_returns(probe)
    vim.fn.writefile(probe, probe_file)
    vim.fn.writefile({ '#!/bin/sh', 'cat >/dev/null 2>&1', "cat '" .. probe_file .. "'" }, fake_client)
    vim.fn.setfperm(fake_client, 'rwx------')
    vim.g.db_sybase_client = fake_client
    return confirm { scheme = 'sybase', host = 'h', path = '/target', params = {} }
end

local unknown = confirm_returns { 'DDB~other_db' }
fail(
    unknown.result == 'indeterminate',
    "an unreadable probe is 'indeterminate', not absent",
    unknown.result,
    'indeterminate'
)
fail(type(unknown.exists) == 'string', 'an unreadable probe keeps exists as a String', type(unknown.exists), 'string')
fail(
    unknown.reason ~= nil and unknown.reason ~= '',
    'an indeterminate outcome carries a reason',
    unknown.reason,
    '<non-empty>'
)
fail(
    unknown.reason:find('does not exist', 1, true) == nil and unknown.reason:find('could not enter', 1, true) == nil,
    'an indeterminate reason names neither absence nor refusal',
    unknown.reason,
    '<neither "does not exist" nor "could not enter">'
)

local absent = confirm_returns { 'DDB~other_db', 'DEX~0' }
fail(absent.result == 'rejected_absent', 'a completed probe reporting zero is absent', absent.result, 'rejected_absent')
fail(absent.exists == 0, 'a completed probe reporting zero keeps exists = 0', absent.exists, 0)
fail(absent.reason ~= nil and absent.reason ~= '', 'an absent outcome carries a reason', absent.reason, '<non-empty>')

local forbidden = confirm_returns { 'DDB~other_db', 'DEX~1' }
fail(
    forbidden.result == 'rejected_forbidden',
    'a completed probe reporting one is forbidden',
    forbidden.result,
    'rejected_forbidden'
)
fail(forbidden.exists == 1, 'a completed probe reporting one keeps exists = 1', forbidden.exists, 1)
fail(
    forbidden.reason ~= nil and forbidden.reason ~= '',
    'a forbidden outcome carries a reason',
    forbidden.reason,
    '<non-empty>'
)

local confirmed = confirm_returns { 'DDB~target' }
fail(confirmed.result == 'confirmed', 'a matching switch is confirmed', confirmed.result, 'confirmed')
fail(confirmed.reason == '', 'a confirmed outcome carries no reason', confirmed.reason, "''")

local no_db = confirm { scheme = 'sybase', host = 'h', path = '/', params = {} }
fail(no_db.result == 'no_database', 'a URL without a database reports no_database', no_db.result, 'no_database')
fail(no_db.reason ~= nil and no_db.reason ~= '', 'no_database carries a reason', no_db.reason, '<non-empty>')

vim.fn.delete(probe_file)
vim.fn.delete(fake_client)
vim.g.db_sybase_client = nil
