-- db_jump smoke test.
-- Asserts <leader>q toggle behavior (FR-023): from code jumps to the DB
-- drawer window first, then to any buffer carrying b:db; from the DB workspace
-- returns to the previously recorded code window; with no DB window open it
-- opens the drawer (DBUIToggle) and focuses it. Exits with code 1 via :cquit on
-- any assertion failure.

local M = require 'config.db_jump'

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

local function new_buf(filetype, with_db)
    local buf = vim.api.nvim_create_buf(true, true)
    vim.bo[buf].filetype = filetype
    if with_db then
        vim.b[buf].db = 'sybase://u@dev/master'
    end
    return buf
end

local function cur_ft()
    return vim.bo[vim.api.nvim_get_current_buf()].filetype
end

local drawer = new_buf('dbui', false)
local code = new_buf('lua', false)
local query = new_buf('sql', true)

-- No DB window open yet: jump() must open the drawer via DBUIToggle.
local toggle_called = 0
vim.api.nvim_create_user_command('DBUIToggle', function()
    toggle_called = toggle_called + 1
    vim.api.nvim_open_win(drawer, true, { split = 'left' })
end, { force = true })

vim.api.nvim_set_current_buf(code)
local code_win = vim.api.nvim_get_current_win()

local target = M.jump()
check(toggle_called == 1, 'jump opens drawer when none open', toggle_called, 1)
check(
    target == vim.api.nvim_get_current_win(),
    'jump focuses drawer after open',
    target,
    vim.api.nvim_get_current_win()
)
check(cur_ft() == 'dbui', 'current buffer is the drawer after open', cur_ft(), 'dbui')

-- From the DB workspace, jump() returns to the previously recorded code window.
local returned = M.jump()
check(
    returned == vim.api.nvim_get_current_win(),
    'jump from DB returns to a window',
    returned,
    vim.api.nvim_get_current_win()
)
check(cur_ft() == 'lua', 'current buffer is code after return', cur_ft(), 'lua')

-- Close the drawer and open a standalone query buffer (no drawer): jump() from
-- code must target the buffer carrying b:db.
vim.api.nvim_win_close(target, true)
local query_win = vim.api.nvim_open_win(query, true, { split = 'right' })
vim.api.nvim_set_current_win(code_win)
local query_target = M.jump()
local query_buf = vim.api.nvim_win_get_buf(query_target)
check(
    vim.b[query_buf].db ~= nil,
    'jump targets b:db buffer when drawer gone',
    vim.b[query_buf].db,
    'sybase://u@dev/master'
)

-- Toggle helper with no previous window recorded must not crash.
local ok, err = pcall(M.back)
check(ok, 'back without history is a no-op', err, nil)

vim.api.nvim_win_close(query_win, true)
vim.api.nvim_buf_delete(drawer, { force = true })
vim.api.nvim_buf_delete(query, { force = true })
vim.api.nvim_buf_delete(code, { force = true })
vim.api.nvim_del_user_command 'DBUIToggle'
vim.print 'All db_jump smoke assertions passed'
