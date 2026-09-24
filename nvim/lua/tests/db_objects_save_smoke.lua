-- Procedure save dialog smoke test (specs/002-procedure-save-dialog, quickstart
-- automated check 4). Asserts the pure, headless-testable parts of the save
-- flow in nvim/lua/config/db_objects.lua:
--   - suggest_save_name: database-qualified naming, fallback, collision-freedom
--   - write_source: byte-exact roundtrip + actionable failure on bad target
--   - needs_confirmation: overwrite guard before/after a file exists
--   - default_save_dir: startup root seeded by setup(); never mutated (US2)
-- The UI steps (pick_save_target/confirm_overwrite via vim.ui.select) are
-- interactive and covered by manual acceptance in quickstart.md.
-- Exits with code 1 via :cquit on any assertion failure.

local M = require 'config.db_objects'

local select_calls = {}
local input_calls = {}
local notices = {}
local writes = {}

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
        vim.print 'FAIL expected a vim.ui.select call (none pending)'
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

local function pick_tag(choices, tag)
    for _, c in ipairs(choices) do
        if c.tag == tag then
            return c
        end
    end
    vim.print('FAIL could not find saver choice with tag ' .. vim.inspect(tag))
    vim.cmd 'cquit'
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
local real_writefile = vim.fn.writefile
vim.fn.writefile = function(lines, path)
    table.insert(writes, vim.fs.normalize(path))
    return real_writefile(lines, path)
end

-- US1/US3: file naming (FR-006)
fail(
    M.suggest_save_name('dev_db', 'usp_calc') == 'dev_db.usp_calc.sql',
    'suggest_save_name qualifies by owning database',
    M.suggest_save_name('dev_db', 'usp_calc'),
    'dev_db.usp_calc.sql'
)
fail(
    M.suggest_save_name(nil, 'usp_calc') == 'usp_calc.sql',
    'suggest_save_name falls back to plain name',
    M.suggest_save_name(nil, 'usp_calc'),
    'usp_calc.sql'
)
fail(
    M.suggest_save_name('', 'usp_calc') == 'usp_calc.sql',
    'suggest_save_name treats empty database as absent',
    M.suggest_save_name('', 'usp_calc'),
    'usp_calc.sql'
)
fail(
    M.suggest_save_name('db1', 'proc') ~= M.suggest_save_name('db2', 'proc'),
    'same-named procedures from different databases do not collide',
    { M.suggest_save_name('db1', 'proc'), M.suggest_save_name('db2', 'proc') },
    'two distinct names'
)

-- US1: byte-exact write roundtrip in a temp dir (FR-005)
local tmp = vim.fn.tempname()
vim.fn.mkdir(tmp, 'p')
local src = {
    'create procedure usp_long as',
    '  -- a line longer than 255 bytes: ' .. string.rep('x', 300),
    '  select 1',
    'go',
}

fail(
    not M.needs_confirmation(tmp, 'usp_long.sql'),
    'overwrite guard is false for a new file',
    M.needs_confirmation(tmp, 'usp_long.sql'),
    false
)

local ok = M.write_source(src, tmp, 'usp_long.sql')
fail(
    ok.ok == true and vim.fn.filereadable(ok.path) == 1,
    'write_source succeeds and creates the file',
    ok,
    { ok = true }
)

local read_back = vim.fn.readfile(vim.fs.joinpath(tmp, 'usp_long.sql'))
fail(vim.deep_equal(read_back, src), 'write_source roundtrip is byte-exact (incl. >255-byte line)', read_back, src)

fail(
    M.needs_confirmation(tmp, 'usp_long.sql'),
    'overwrite guard is true once the file exists',
    M.needs_confirmation(tmp, 'usp_long.sql'),
    true
)

-- US1: failure path (FR-009)
local bad = vim.fs.joinpath(tmp, 'does-not-exist') -- parent does not exist
local failed = M.write_source(src, bad, 'usp_long.sql')
fail(
    failed.ok == false and type(failed.error) == 'string' and failed.error ~= '',
    'write_source to a non-existent target returns an actionable error',
    failed,
    { ok = false, error = '<message>' }
)

-- US2: startup root default is seeded once and never mutated (FR-002/FR-003)
local root = vim.fs.joinpath(tmp, 'launch-root')
M.setup(root)
fail(
    M.default_save_dir() == vim.fs.normalize(root),
    'default_save_dir reflects the startup root from setup()',
    M.default_save_dir(),
    vim.fs.normalize(root)
)
local flow = M.run_save_flow -- UI flow is interactive; asserting it exists as a callable entry
fail(type(flow) == 'function', 'run_save_flow entry is a function', type(flow), 'function')
fail(
    M.default_save_dir() == vim.fs.normalize(root),
    'default dir is not mutated by touching the flow',
    M.default_save_dir(),
    vim.fs.normalize(root)
)

-- US2 (007): save confirmation notification (FR-006/FR-007, contract §3) -----
--
-- Drive run_save_flow headlessly: pick_save_target -> [type a path…] ->
-- vim.ui.input(relative) -> create-directory confirm -> write_source -> notify.
local flow_row = { name = 'usp_flow', database = 'flow_db' }
local flow_lines = { 'create procedure usp_flow as', 'go' }
local dest = vim.fs.joinpath(root, 'dest')

-- fresh save to a relative typed path
local writes_before = #writes
local notices_before = #notices
M.run_save_flow(flow_row, flow_lines)
local saver = next_select()
fail(
    saver.opts.prompt:find('Save procedure to', 1, true) ~= nil,
    'US2: save picker opens from run_save_flow',
    saver.opts.prompt,
    '<Save procedure to>'
)
saver.cb(pick_tag(saver.items, 'type'))
next_input().cb 'dest'
local create_dir = next_select()
fail(
    create_dir.items[1] == 'Create directory',
    'US2: typed non-existent path asks to create the directory',
    create_dir.items,
    '{"Create directory", "Cancel"}'
)
create_dir.cb 'Create directory'
fail(#writes == writes_before + 1, 'US2: fresh save writes exactly one file', #writes, writes_before + 1)
fail(#notices == notices_before + 1, 'US2: fresh save fires exactly one notification', #notices, notices_before + 1)
local saved_notice = notices[#notices]
fail(
    saved_notice ~= nil
        and saved_notice.msg:find('flow_db.usp_flow.sql', 1, true) ~= nil
        and saved_notice.msg:find(dest, 1, true) ~= nil
        and saved_notice.level == vim.log.levels.INFO,
    'US2: notification carries the full resolved path and filename',
    saved_notice,
    '<DBObjects: saved <dest>/flow_db.usp_flow.sql>'
)
local wrote_once = 0
for _, p in ipairs(writes) do
    if p:find('flow_db.usp_flow.sql', 1, true) then
        wrote_once = wrote_once + 1
    end
end
fail(wrote_once == 1, 'US2: flow file exists exactly once across all writes', wrote_once, 1)
fail(
    vim.fn.filereadable(vim.fs.joinpath(dest, 'flow_db.usp_flow.sql')) == 1,
    'US2: file exists in the confirmed destination',
    vim.fn.filereadable(vim.fs.joinpath(dest, 'flow_db.usp_flow.sql')),
    1
)
fail(
    vim.fn.filereadable(vim.fs.joinpath(root, 'flow_db.usp_flow.sql')) == 0,
    'US2: no file leaked into the startup root',
    vim.fn.filereadable(vim.fs.joinpath(root, 'flow_db.usp_flow.sql')),
    0
)

-- overwrite-confirmed save fires one notification, one write
local ow_before_writes = #writes
local ow_before_notices = #notices
M.run_save_flow(flow_row, flow_lines)
local ow_saver = next_select()
ow_saver.cb(pick_tag(ow_saver.items, 'type'))
next_input().cb 'dest'
local ow_confirm = next_select()
fail(
    ow_confirm.items[1] == 'Overwrite' and ow_confirm.items[2] == 'Keep existing (cancel)',
    'US2: existing file triggers the overwrite guard',
    ow_confirm.items,
    '{"Overwrite", "Keep existing (cancel)"}'
)
ow_confirm.cb 'Overwrite'
fail(#writes == ow_before_writes + 1, 'US2: overwrite save writes exactly one file', #writes, ow_before_writes + 1)
fail(
    #notices == ow_before_notices + 1,
    'US2: overwrite save fires exactly one notification',
    #notices,
    ow_before_notices + 1
)

-- keep-existing (cancel) is a no-op: no write, no notification
local cancel_before_writes = #writes
local cancel_before_notices = #notices
M.run_save_flow(flow_row, flow_lines)
local cancel_saver = next_select()
cancel_saver.cb(pick_tag(cancel_saver.items, 'type'))
next_input().cb 'dest'
local cancel_confirm = next_select()
cancel_confirm.cb 'Keep existing (cancel)'
fail(#writes == cancel_before_writes, 'US2: keep-existing writes nothing', #writes, cancel_before_writes)
fail(#notices == cancel_before_notices, 'US2: keep-existing fires no notification', #notices, cancel_before_notices)

-- dialog always starts at the startup root (FR-008)
M.run_save_flow(flow_row, flow_lines)
local start_saver = next_select()
fail(
    start_saver.items[1].label:find(vim.fs.normalize(root), 1, true) ~= nil,
    'US2: save picker always starts at the startup root',
    start_saver.items[1].label,
    '[save here: <startup root>]'
)

vim.fn.delete(tmp, 'rf')
vim.print 'All db_objects save smoke assertions passed'
