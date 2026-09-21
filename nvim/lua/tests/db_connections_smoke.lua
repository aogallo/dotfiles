-- Registry-load test (quickstart automated check 5).
-- Asserts g:dbs matches the registry file behind NVIM_DB_CONNECTIONS, that the
-- registry reloads when the DBUI buffer is re-entered (FR-006), and that a
-- missing or unparsable file yields an empty registry without crashing.
-- Exits with code 1 via :cquit on any assertion failure.

local loader_path = 'config.db_connections'

local function check(ok, name, got, want)
    if ok then
        vim.print('PASS ' .. name)
        return
    end
    vim.print('FAIL ' .. name)
    vim.print('  got:  ' .. vim.inspect(got))
    vim.print('  want: ' .. vim.inspect(want))
    vim.cmd 'cquit'
end

local function write_registry(path, entries)
    local lines = { 'return {' }
    for name, url in pairs(entries) do
        table.insert(lines, '  ' .. name .. ' = ' .. vim.inspect(url) .. ',')
    end
    table.insert(lines, '}')
    vim.fn.writefile(lines, path)
end

local function reliable_require()
    package.loaded[loader_path] = nil
    return require(loader_path)
end

local reg_file = vim.fn.tempname() .. '-db-connections.lua'
local entries_a = {
    sybase_dev = 'sybase://u:pass@ase-dev:5000/app_db',
    mongo_local = 'mongodb://localhost:27017/app_db',
}

write_registry(reg_file, entries_a)
vim.env.NVIM_DB_CONNECTIONS = reg_file
reliable_require()
check(vim.deep_equal(vim.g.dbs, entries_a), 'registry populates g:dbs from NVIM_DB_CONNECTIONS', vim.g.dbs, entries_a)

local entries_b = {
    sybase_dev = 'sybase://u:pass@ase-dev:5000/app_db',
    mongo_local = 'mongodb://localhost:27017/app_db',
    sqlserver_dev = 'sqlserver://dev:pass@sql-dev:1433/AppDb',
}
write_registry(reg_file, entries_b)

local scratch = vim.api.nvim_create_buf(true, false)
vim.bo[scratch].filetype = 'dbui'
vim.cmd('buffer ' .. scratch)
check(vim.deep_equal(vim.g.dbs, entries_b), 'registry reloads on DBUI buffer enter (FR-006)', vim.g.dbs, entries_b)

vim.env.NVIM_DB_CONNECTIONS = nil
vim.g.dbs = { leftover = 'should-be-replaced' }
local scratch2 = vim.api.nvim_create_buf(true, false)
vim.bo[scratch2].filetype = 'dbui'
vim.cmd('buffer ' .. scratch2)
check(vim.deep_equal(vim.g.dbs, {}), 'missing registry -> empty registry, no crash', vim.g.dbs, {})

local bad_file = vim.fn.tempname() .. '-bad.lua'
vim.fn.writefile({ 'return { broken syntax' }, bad_file)
vim.env.NVIM_DB_CONNECTIONS = bad_file
local ok = pcall(reliable_require)
check(ok and vim.deep_equal(vim.g.dbs, {}), 'unparsable registry -> warn + empty, no crash', ok, true)

vim.env.NVIM_DB_CONNECTIONS = nil
vim.fn.delete(reg_file)
vim.fn.delete(bad_file)
vim.api.nvim_buf_delete(scratch, { force = true })
vim.api.nvim_buf_delete(scratch2, { force = true })
