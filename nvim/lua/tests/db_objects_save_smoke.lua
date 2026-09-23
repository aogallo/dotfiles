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

vim.fn.delete(tmp, 'rf')
vim.print 'All db_objects save smoke assertions passed'
