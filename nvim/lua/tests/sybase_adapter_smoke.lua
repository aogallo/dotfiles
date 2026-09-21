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
local isql_base = { 'isql', '-S', 'h:5000', '-U', 'u', '-P', 'p', '-D', 'db' }
local got_isql = interactive(url)
fail(vim.deep_equal(got_isql, isql_base), 'isql interactive argv', got_isql, isql_base)

local infile = vim.fn.tempname() .. '.sql'
local batch = { 'select 1', 'go', ' GO ', 'print 2', 'go' }
vim.fn.writefile(batch, infile)

local got_isql_input = input(url, infile)
local want_isql_input = { 'isql', '-S', 'h:5000', '-U', 'u', '-P', 'p', '-D', 'db', '-i', infile }
fail(vim.deep_equal(got_isql_input, want_isql_input), 'isql input argv (no transform)', got_isql_input, want_isql_input)

vim.g.db_sybase_client = 'sqsh'
local sqsh_base = { 'sqsh', '-S', 'h:5000', '-U', 'u', '-P', 'p', '-D', 'db', '-L', 'semicolon_hack=false' }
local got_sqsh = interactive(url)
fail(vim.deep_equal(got_sqsh, sqsh_base), 'sqsh interactive argv', got_sqsh, sqsh_base)

local got_sqsh_input = input(url, infile)
local want_sqsh_prefix =
    { 'sqsh', '-S', 'h:5000', '-U', 'u', '-P', 'p', '-D', 'db', '-L', 'semicolon_hack=false', '-i' }
fail(
    vim.deep_equal(vim.list_slice(got_sqsh_input, 1, 12), want_sqsh_prefix),
    'sqsh input argv prefix',
    got_sqsh_input,
    want_sqsh_prefix
)

local copy = got_sqsh_input[#got_sqsh_input]
local copy_lines = vim.fn.readfile(copy)
fail(
    vim.deep_equal(copy_lines, { 'select 1', '\\go', '\\go', 'print 2', '\\go' }),
    'sqsh input transformed copy (go -> \\go)',
    copy_lines,
    { 'select 1', '\\go', '\\go', 'print 2', '\\go' }
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
local want_probe =
    { 'sqsh', '-S', 'h:5000', '-U', 'u', '-P', 'p', '-D', 'db', '-L', 'semicolon_hack=false', '-i', missing_probe }
fail(vim.deep_equal(got_probe, want_probe), 'sqsh input probe passes missing temp through', got_probe, want_probe)

vim.fn.delete(copy)
vim.fn.delete(infile)
vim.g.db_sybase_client = nil
