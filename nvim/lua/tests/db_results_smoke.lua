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
-- 4b. A summoned result must come back as a drawer, not as a tab
-- (specs/011-query-buffer-tab-visibility, R-0008; FR-018). `:pedit` re-derives
-- buffer options from the file, so without re-applying them the summon handed
-- generated output a tab in bufferline.
local summoned = vim.fn.bufnr(outfile)
check(not vim.bo[summoned].buflisted, 'a reopened result takes no tab', vim.bo[summoned].buflisted, false)
check(vim.bo[summoned].readonly, 'a reopened result is read-only', vim.bo[summoned].readonly, true)
check(not vim.bo[summoned].modifiable, 'a reopened result is nomodifiable', vim.bo[summoned].modifiable, false)
check(
    vim.bo[summoned].bufhidden == 'delete',
    'a reopened result keeps bufhidden=delete',
    vim.bo[summoned].bufhidden,
    'delete'
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

--- classification and reporting (specs/archive/2026-10-01-001-surface-query-errors, US1) --------

-- Fixtures are the client's own output shapes; no server and no client binary
-- are involved. M.classify() is the pure seam, then the listener is driven
-- through the same autocmd dadbod raises.
local function fixture(lines)
    local path = vim.fn.tempname() .. '.dbout'
    vim.fn.writefile(lines, path)
    return path
end

-- 6. One complaint: the server's words, with the prose that follows the header.
local one = M.classify {
    'Msg 156, Level 15, State 1, Server srv, Line 1',
    "Incorrect syntax near the keyword 'FROM'.",
}
check(one.kind == 'failed', 'a complaint classifies as failed', one.kind, 'failed')
check(#one.complaints == 1, 'one complaint is captured', #one.complaints, 1)
if #one.complaints == 1 then
    check(one.complaints[1].code == 156, 'the complaint code is parsed', one.complaints[1].code, 156)
    check(one.complaints[1].level == 15, 'the complaint level is parsed', one.complaints[1].level, 15)
    check(
        one.complaints[1].text:find('Incorrect syntax', 1, true) ~= nil,
        'the complaint prose is kept',
        one.complaints[1].text,
        'mentions Incorrect syntax'
    )
end

-- 7. Two complaints: every one is kept, not just the first (FR-004).
local two = M.classify {
    'Msg 156, Level 15, State 1, Server srv, Line 1',
    "Incorrect syntax near 'FROM'.",
    'Msg 102, Level 15, State 1, Server srv, Line 3',
    "Incorrect syntax near ')'.",
}
check(two.kind == 'failed', 'two complaints classify as failed', two.kind, 'failed')
check(#two.complaints == 2, 'both complaints are captured', #two.complaints, 2)

-- 8. Complaint plus partial rows: both survive and stay distinguishable (FR-026).
local mixed = M.classify {
    'col1|col2',
    'a|1',
    'Msg 50000, Level 16, State 1, Server srv, Line 2',
    'Divide by zero occurred.',
}
check(mixed.kind == 'failed', 'a complaint beside rows is still failed', mixed.kind, 'failed')
check(#mixed.rows == 2, 'partial rows are retained', mixed.rows, { 'col1|col2', 'a|1' })
check(mixed.row_count == 2, 'the row count matches the retained rows', mixed.row_count, 2)
check(#mixed.complaints == 1, 'the complaint is retained beside the rows', #mixed.complaints, 1)

-- 9. Zero rows and no complaint is a success, never a failure (FR-007, SC-004).
local empty = M.classify {}
check(empty.kind == 'success', 'an empty response is a success', empty.kind, 'success')
check(empty.row_count == 0, 'an empty response has zero rows', empty.row_count, 0)
for i = 1, 10 do
    local zero = M.classify { '', ' ' }
    check(zero.kind == 'success', 'zero-row response ' .. i .. ' is not a failure', zero.kind, 'success')
end

-- 10. Unrecognized non-zero output is a warning, never silence (FR-012).
local unknown = M.classify({ 'ct_something: not a shape we know' }, { exit_status = 1 })
check(unknown.kind == 'unreadable', 'unrecognized output degrades to unreadable', unknown.kind, 'unreadable')

-- 11. A cancelled run is its own outcome, not a failure (FR-002).
local cancelled = M.classify({ 'Msg 156, Level 15, State 1, Server srv, Line 1' }, { cancelled = true })
check(cancelled.kind == 'cancelled', 'a cancelled run is cancelled', cancelled.kind, 'cancelled')

-- 12. The listener reports the server's complaint exactly once per run (FR-001, FR-027).
local complaint_file = fixture {
    'Msg 156, Level 15, State 1, Server srv, Line 1',
    "Incorrect syntax near the keyword 'FROM'.",
}
local complaint_buf = vim.fn.bufadd(complaint_file)
vim.fn.bufload(complaint_buf)
clear_notices()
fire('DBExecutePost', complaint_file)
check(seen 'Incorrect syntax', 'the listener notice names the server complaint', notices, 'Incorrect syntax')
check(#notices == 1, 'the failed run reports exactly one notice', #notices, 1)
fire('DBExecutePost', complaint_file)
check(#notices == 1, 'observing the same run twice does not duplicate the notice', #notices, 1)

-- 13. The full response stays readable afterwards, byte for byte (FR-005, FR-014, FR-025).
local recorded = M._current_slot()
local on_disk = vim.fn.readfile(complaint_file)
check(
    table.concat(recorded.lines, '\n') == table.concat(on_disk, '\n'),
    'the full response is retained unmodified',
    recorded.lines,
    on_disk
)
check(
    recorded.outcome and recorded.outcome.kind == 'failed',
    'the slot records the failed outcome',
    recorded.outcome and recorded.outcome.kind,
    'failed'
)

-- 14. A run that reports partial rows beside a complaint keeps both, and they
-- stay distinguishable (FR-026).
local partial_file = fixture {
    'col1|col2',
    'a|1',
    'Msg 50000, Level 16, State 1, Server srv, Line 2',
    'Divide by zero occurred.',
}
fire('DBExecutePost', partial_file)
local partial = M._current_slot()
check(partial.outcome.kind == 'failed', 'a complaint beside rows is a failure', partial.outcome.kind, 'failed')
check(
    #partial.outcome.rows == 2 and partial.outcome.rows[1] == 'col1|col2',
    'the partial rows are retained and distinguishable from the complaint',
    partial.outcome.rows,
    { 'col1|col2', 'a|1' }
)
check(#partial.outcome.complaints == 1, 'the complaint is retained beside the rows', #partial.outcome.complaints, 1)

-- 15. The stored server response is the server's text alone: the editor's own
-- locator or hint text never enters it (FR-014, FR-025).
local stored = table.concat(partial.lines, '\n')
check(
    stored:find('DB: query from', 1, true) == nil,
    "the editor's locator never enters the server text",
    stored,
    '<no DB: line>'
)
check(
    stored:find('Divide by zero', 1, true) ~= nil,
    'the server text is present in the stored response',
    stored,
    '<Divide by zero>'
)

-- 16. Two different failing runs each get their own notice (FR-027, SC-013).
local second_file = fixture {
    'Msg 102, Level 15, State 1, Server srv, Line 1',
    "Incorrect syntax near ')'.",
}
clear_notices()
fire('DBExecutePost', second_file)
check(
    seen "Incorrect syntax near ')'",
    'a second distinct failure reports its own complaint',
    notices,
    "<Incorrect syntax near ')'>"
)
check(#notices == 1, 'the second distinct failure reports exactly one notice', #notices, 1)

-- Cleanup.
vim.api.nvim_win_close(code_win, true)
vim.api.nvim_buf_delete(code_buf, { force = true })
os.remove(outfile)
pcall(vim.api.nvim_buf_delete, complaint_buf, { force = true })
os.remove(complaint_file)
os.remove(partial_file)
os.remove(second_file)
vim.notify = original_notify
vim.print 'All db_results smoke assertions passed'
