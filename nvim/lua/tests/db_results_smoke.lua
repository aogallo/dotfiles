-- db_results smoke test.
-- Drives the `User */DBExecutePre|Post` autocallbacks directly via
-- nvim_exec_autocmds with a temporary `.dbout` file (no live database, no
-- plugins) and asserts the summon path (specs/archive/2026-09-23-006-dbui-query-results, US1):
--   . no record -> exactly one INFO notice, nothing created
--   . running (Pre without Post) -> one INFO notice, no-op
--   . Post records the result -> summon focuses the open window
--   . window closed and buffer wiped -> summon reopens the temp file (:pedit)
--   . output file missing -> one WARN notice, no buffer created
-- Exits with code 1 via :cquit on any assertion failure.

local M = require 'config.db_results'

M.setup()

local original_notify = vim.notify
local notices = {}
vim.notify = function(msg, level, _opts)
    table.insert(notices, { msg = tostring(msg), level = level })
end

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

local function clear_notices()
    notices = {}
end

local function seen(expect)
    for _, n in ipairs(notices) do
        if n.msg:find(expect, 1, true) then
            return true
        end
    end
    return false
end

local function fire(event, outfile)
    vim.api.nvim_exec_autocmds('User', { pattern = outfile .. '/' .. event })
end

local outfile = vim.fn.tempname() .. '.dbout'
vim.fn.writefile({ 'col1|col2', 'a|1', 'b|2' }, outfile)
local missing = vim.fn.tempname() .. '.dbout'

local bufs_before = #vim.api.nvim_list_bufs()

-- 1. No query finished yet: exactly one info notice, nothing created.
clear_notices()
local target = M.show()
check(not target, 'show with no record returns nil', target, nil)
check(
    seen 'no query result recorded yet',
    'show with no record emits one info notice',
    notices,
    'no query result recorded yet'
)
check(#notices == 1, 'show with no record emits exactly one notice', #notices, 1)
check(
    #vim.api.nvim_list_bufs() == bufs_before,
    'show with no record creates no buffer',
    #vim.api.nvim_list_bufs(),
    bufs_before
)

-- 2. Query still running (Pre fired, Post not yet): no-op notice.
clear_notices()
fire('DBExecutePre', outfile)
target = M.show()
check(not target, 'show while running returns nil', target, nil)
check(seen 'query still running', 'show while running notifies', notices, 'query still running')
check(
    #vim.api.nvim_list_bufs() == bufs_before,
    'show while running creates no buffer',
    #vim.api.nvim_list_bufs(),
    bufs_before
)

-- 3. Finished result, window open but elsewhere: summon focuses it.
vim.cmd.pedit(vim.fn.fnameescape(outfile))
local preview_win = vim.fn.win_findbuf(vim.fn.bufnr(outfile))[1]
local result_buf = vim.api.nvim_win_get_buf(preview_win)
fire('DBExecutePost', outfile)

local code_buf = vim.api.nvim_create_buf(true, true)
local code_win = vim.api.nvim_open_win(code_buf, true, { split = 'right' })
vim.api.nvim_set_current_win(code_win)

clear_notices()
local focused = M.show()
check(focused == preview_win, 'show focuses the existing result window', focused, preview_win)
check(
    vim.api.nvim_get_current_buf() == result_buf,
    'show leaves the result buffer current',
    vim.api.nvim_get_current_buf(),
    result_buf
)

-- Idempotency: repeated summons converge on the same window, no new buffers.
local bufs_before_idem = #vim.api.nvim_list_bufs()
local again = M.show()
check(again == focused, 'repeated summon focuses the same window', again, focused)
check(
    #vim.api.nvim_list_bufs() == bufs_before_idem,
    'repeated summon creates no buffers',
    #vim.api.nvim_list_bufs(),
    bufs_before_idem
)

-- 4. Result window closed and buffer wiped: summon reopens the file.
vim.api.nvim_win_close(preview_win, true)
vim.api.nvim_buf_delete(result_buf, { force = true })

clear_notices()
local reopened = M.show()
check(reopened ~= nil, 'show reopens a closed result', reopened, 'a window id')
check(
    vim.fn.bufname(vim.api.nvim_win_get_buf(reopened)) == outfile,
    'reopened window shows the recorded output file',
    vim.fn.bufname(vim.api.nvim_win_get_buf(reopened)),
    outfile
)
check(
    reopened == vim.api.nvim_get_current_win(),
    'reopened result takes focus',
    reopened,
    vim.api.nvim_get_current_win()
)
vim.api.nvim_win_close(reopened, true)

-- 5. Output file gone from disk: one warning notice, no buffer created.
fire('DBExecutePost', missing)
local bufs_now = #vim.api.nvim_list_bufs()
clear_notices()
target = M.show()
check(not target, 'show with missing file returns nil', target, nil)
check(seen 'output file no longer exists', 'show with missing file warns', notices, 'output file no longer exists')
check(#notices == 1, 'show with missing file emits exactly one notice', #notices, 1)
check(
    #vim.api.nvim_list_bufs() == bufs_now,
    'show with missing file creates no buffer',
    #vim.api.nvim_list_bufs(),
    bufs_now
)

-- Cleanup.
vim.api.nvim_win_close(code_win, true)
vim.api.nvim_buf_delete(code_buf, { force = true })
os.remove(outfile)
vim.notify = original_notify
vim.print 'All db_results smoke assertions passed'
