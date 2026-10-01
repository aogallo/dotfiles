-- Summon the last finished dadbod query result from any tab and window.
--
-- dadbod renders each query result in a preview window (`:pedit`) backed by a
-- `nobuflisted`/`bufhidden=delete` buffer over a temp `.dbout` file. Dadbod
-- publishes `User */DBExecutePre|Post` autocmds whose match name is that output
-- file; this module records the finished result (file path + buffer) in a single
-- per-session slot and `<leader>qr` either focuses its window or reopens the
-- file when the preview window was closed.
--
-- The native dadbod `DB: Query finished in ...` command-line echo stays (not
-- configurable upstream). This module never alters query execution and never
-- touches the DBUI drawer's "Query results" list (contracts/db-results.md).
--
-- DOCUMENTATION CONVENTION (see nvim/README.md, "Documenting a function"):
--   every function carries a header with Purpose / Called by / SQL / Args /
--   Returns / Side effects. Required for new functions too.

local M = {}

local slot = { outfile = nil, bufnr = nil, running = false, outcome = nil, lines = nil, query_buf = nil }

local setup_done = false
local diagnostics_done = false

-- The ASE complaint header already used across the module (sybase.vim:510). The
-- classifier recognizes this one shape and nothing client-specific beyond it, so
-- a client that words things differently degrades to M.classify()'s fail-closed
-- default rather than being silently treated as a success.
local MSG_HEADER = '^Msg%s+(%d+)%s*,%s*Level%s+(%d+)'

-- Runs whose notice was already emitted, keyed by output path plus notice text,
-- so a run that is observed twice does not report twice (FR-027).
local notified = {}

-- trim(value): strip leading and trailing whitespace.
-- Called by: M.classify(), origin_label()
-- SQL: none
-- Args: value = any value (coerced with tostring)
-- Returns: the value without surrounding whitespace
-- Side effects: none
local function trim(value)
    return (tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', ''))
end

-- origin_label(run): the line naming the buffer the failing query came from.
-- Called by: M.notice_text()
-- SQL: none
-- Args: run = the per-session slot
-- Returns: a short locator line, or '' when no usable buffer name is known
-- Side effects: none
--
-- A buffer name can be a connection URL, which may carry credentials, so a URL
-- name is reduced to its last path component and never rendered whole (FR-031).
local function origin_label(run)
    if not run or not run.query_buf or run.query_buf <= 0 then
        return ''
    end
    if not vim.api.nvim_buf_is_valid(run.query_buf) then
        return ''
    end
    local name = vim.api.nvim_buf_get_name(run.query_buf)
    if name == '' then
        return 'DB: query from an unnamed buffer'
    end
    if name:find('://', 1, true) then
        name = vim.fn.fnamemodify(name, ':t')
        if name == '' then
            return ''
        end
    end
    return 'DB: query from ' .. name
end

-- on_pre(): mark the latest query as still running.
-- Called by: the `User */DBExecutePre` autocmd registered in M.setup()
-- SQL: none
-- Args: none (autocmd callback)
-- Returns: nothing
-- Side effects: sets slot.running = true, which makes M.show() refuse to
--   summon a half-written result file, and records the buffer the query ran from
--   so a later failure notice can name it
local function on_pre()
    slot.running = true
    slot.query_buf = vim.api.nvim_get_current_buf()
end

-- on_post(args): record the finished result (output file + its buffer).
-- Called by: the `User */DBExecutePost` autocmd registered in M.setup()
-- SQL: none
-- Args: args.match = the matched event pattern, which dadbod fires as
--   `<output file>/DBExecutePost` (the `*` in the registered pattern)
-- Returns: nothing
-- Side effects: writes slot.outfile/slot.bufnr and clears slot.running
--
-- The `:h` is load-bearing and easy to misread: it strips the trailing
-- `DBExecutePost` component and leaves the .dbout file itself. Taking `:t` or
-- treating the result as a directory would break M.show() (measured, R-0008).
local function on_post(args)
    slot.outfile = vim.fn.fnamemodify(args.match, ':h')
    slot.bufnr = vim.fn.bufnr(slot.outfile)
    slot.running = false
end

-- M._current_slot(): the per-session record of the last finished run.
-- Called by: the diagnostics listener in M.setup_diagnostics(), and the tests
-- SQL: none
-- Args: none
-- Returns: the slot table (outfile, bufnr, running, outcome, lines)
-- Side effects: none
function M._current_slot()
    return slot
end

-- M._store(slot, outcome): retain a finished run's classification and full text.
-- Called by: the diagnostics listener in M.setup_diagnostics(), and the tests
-- SQL: none
-- Args: slot = the run record from M._current_slot(), outcome = a RunOutcome
--   whose `lines` field is the complete server response, unmodified
-- Returns: the outcome
-- Side effects: writes slot.outcome and keeps slot.lines = the full response,
--   so a complaint can be reported without re-running the query (FR-025)
function M._store(slot, outcome)
    slot.outcome = outcome
    slot.lines = outcome.lines or {}
    return outcome
end

-- M.classify(lines, opts): classify one completed run's server response.
-- Called by: M.setup_diagnostics()'s listener, and the tests
-- SQL: none
-- Args: lines = the complete response from the output file, in server order,
--   unmodified; opts.cancelled = true when dadbod recorded query.canceled;
--   opts.exit_status = the client's own status (nil when unknown)
-- Returns: a RunOutcome { kind, complaints, rows, row_count, lines } where kind
--   is one of success | failed | cancelled | unreadable
-- Side effects: none (the input is never mutated)
--
-- Ordered recognition rules (contracts/query_diagnostics.lua.md): a cancelled
-- run; any `Msg N, Level N` line (every one captured, FR-004), where the prose
-- that follows a header belongs to that complaint; a non-zero exit with no
-- complaint, which is the fail-closed unreadable default (FR-012); otherwise a
-- success -- zero rows included, which is never a failure (FR-007). The full
-- `lines` are retained so surfacing a complaint never consumes the response
-- (FR-005, FR-025).
function M.classify(lines, opts)
    opts = opts or {}
    lines = lines or {}
    local complaints, rows = {}, {}
    local i, n = 1, #lines
    while i <= n do
        local line = lines[i]
        local code, level = line:match(MSG_HEADER)
        if code then
            local block = { trim(line) }
            local j = i + 1
            while j <= n do
                local next_line = lines[j]
                if trim(next_line) == '' or next_line:match(MSG_HEADER) then
                    break
                end
                block[#block + 1] = trim(next_line)
                j = j + 1
            end
            complaints[#complaints + 1] = {
                code = tonumber(code),
                level = tonumber(level),
                text = table.concat(block, '\n'),
                line_no = i,
            }
            i = j
        else
            if trim(line) ~= '' then
                rows[#rows + 1] = line
            end
            i = i + 1
        end
    end

    local kind
    if opts.cancelled then
        kind = 'cancelled'
    elseif #complaints > 0 then
        kind = 'failed'
    elseif opts.exit_status ~= nil and opts.exit_status ~= 0 then
        kind = 'unreadable'
    else
        kind = 'success'
    end

    return { kind = kind, complaints = complaints, rows = rows, row_count = #rows, lines = lines }
end

-- M.notice_text(outcome, run): the developer-facing text for a failed run.
-- Called by: M._notify_once()
-- SQL: none
-- Args: outcome = a RunOutcome, run = the per-session slot (for the locator)
-- Returns: the server's own complaint text, or a clear "could not read" warning
--   for an unreadable run; '' for a success
-- Side effects: none
--
-- Each complaint's own line breaks are reflowed to spaces so the first
-- complaint is wholly visible in the notification summary, but the words are
-- never rewritten or abbreviated (FR-014). The complaint lines are the server's
-- response; the trailing locator line is the editor's own, kept separate so it
-- is never presented as part of the response (FR-024).
function M.notice_text(outcome, run)
    if outcome.kind == 'failed' then
        local parts = {}
        for _, complaint in ipairs(outcome.complaints) do
            parts[#parts + 1] = (complaint.text:gsub('%s*\n%s*', ' '))
        end
        local message = table.concat(parts, '\n')
        local origin = origin_label(run)
        if origin ~= '' then
            message = message .. '\n' .. origin
        end
        return message
    end
    if outcome.kind == 'unreadable' then
        return 'DB: the server response for the last query could not be read; open the result to inspect it in full'
    end
    return ''
end

-- M._notify_once(slot, outcome): emit one notice per failed run.
-- Called by: the diagnostics listener in M.setup_diagnostics(), and the tests
-- SQL: none
-- Args: slot = the run record, outcome = a failed or unreadable RunOutcome
-- Returns: true when a notice was emitted, false when this run already reported
-- Side effects: one WARN notification built from the server's own complaint
--   text; never renders a connection URL (FR-024, FR-027, FR-031)
function M._notify_once(slot, outcome)
    local message = M.notice_text(outcome, slot)
    if message == '' then
        return false
    end
    local key = (slot.outfile or '') .. '\0' .. message
    if notified[key] then
        return false
    end
    notified[key] = true
    require('notifications').notify(message, vim.log.levels.WARN, { source = 'DB' })
    return true
end

-- M.setup_diagnostics(): register the per-run reporting listener (idempotent).
-- Called by: M.setup(), after on_post's listener is registered
-- SQL: none
-- Args: none
-- Returns: nothing (a second call is a no-op via diagnostics_done)
-- Side effects: creates a second `User */DBExecutePost` autocmd
--
-- Registered after on_post so the run's output path is recorded first, and on
-- the same event dadbod raises once the output file is complete
-- (autoload/db.vim:316 writes it, :329 raises Post). Reading the file rather
-- than the job's line list is load-bearing: db#systemlist() returns [] on a
-- non-zero exit, so the line list is the one source guaranteed to have lost the
-- complaint (R-0005, D-0001). The body is wrapped so a fault in reporting is
-- reported as an internal error and never as a server complaint (FR-011).
function M.setup_diagnostics()
    if diagnostics_done then
        return
    end
    diagnostics_done = true
    vim.api.nvim_create_autocmd('User', {
        pattern = '*/DBExecutePost',
        callback = function()
            local ok, err = pcall(function()
                local run = slot
                if not run.outfile then
                    return
                end
                local preview_buf = vim.fn.bufnr(run.outfile)
                local query = preview_buf > 0 and vim.b[preview_buf].db or nil

                local lines, readable
                if vim.fn.filereadable(run.outfile) == 1 then
                    local read_ok, read_lines = pcall(vim.fn.readfile, run.outfile)
                    readable = read_ok
                    lines = read_ok and read_lines or nil
                end

                local outcome
                if not readable then
                    outcome = { kind = 'unreadable', complaints = {}, rows = {}, row_count = 0, lines = {} }
                else
                    outcome = M.classify(lines, {
                        cancelled = query and query.canceled == 1 or false,
                        exit_status = query and query.exit_status or nil,
                    })
                end

                if outcome.kind == 'failed' or outcome.kind == 'unreadable' then
                    M._notify_once(run, outcome)
                end
                M._store(run, outcome)
            end)
            if not ok then
                pcall(function()
                    require('notifications').notify(
                        'DB: the editor could not inspect the query result: ' .. tostring(err),
                        vim.log.levels.ERROR,
                        { source = 'DB' }
                    )
                end)
            end
        end,
        desc = 'db_results: report the server complaint for the finished run',
    })
end

-- M.setup(): register the dadbod query autocmds (idempotent).
-- Called by: nvim/plugin/database.lua at plugin source time
-- SQL: none
-- Args: none
-- Returns: nothing (a second call is a no-op via setup_done)
-- Side effects: creates the `User */DBExecutePre|Post` autocmds and the
--   reporting listener from M.setup_diagnostics()
function M.setup()
    if setup_done then
        return
    end
    setup_done = true
    vim.api.nvim_create_autocmd('User', {
        pattern = '*/DBExecutePre',
        callback = on_pre,
        desc = 'db_results: mark latest query as running',
    })
    vim.api.nvim_create_autocmd('User', {
        pattern = '*/DBExecutePost',
        callback = on_post,
        desc = 'db_results: record last finished query result',
    })
    M.setup_diagnostics()
end

-- apply_drawer_options(bufnr): put a summoned result back in drawer shape.
-- Called by: M.show(), on the re-open path only
-- SQL: none
-- Args: bufnr = the result buffer just created by `:pedit`
-- Returns: nothing
-- Side effects: sets `buflisted=false`, `bufhidden=delete`, `readonly=true` and
--   `modifiable=false` -- dadbod's own four settings for a result drawer. Note
--   that `nomodifiable` is not an option name: it is expressed as
--   `modifiable=false` (measured -- `vim.bo[b].nomodifiable` is E5108).
--   `:pedit` re-derives buffer options from the file on every re-open, so a
--   result that was dismissed and summoned back would otherwise take a tab in
--   bufferline -- generated output is not something to work in (FR-018, R-0008).
--   Applying them after `:pedit` is the only correct order: `:pedit` is what
--   resets them.
local function apply_drawer_options(bufnr)
    vim.bo[bufnr].bufhidden = 'delete'
    vim.bo[bufnr].readonly = true
    vim.bo[bufnr].modifiable = false
    vim.bo[bufnr].buflisted = false
end

-- focus_win_for(bufnr): move the cursor to a window showing bufnr.
-- Called by: M.show() (both the already-open and the reopened paths)
-- SQL: none
-- Args: bufnr = buffer number
-- Returns: the focused window id, or nil when the buffer is not visible in any
--   window (`:pedit` shows it without focusing it, so this is required)
-- Side effects: changes the current window; prefers a window in the current tab
local function focus_win_for(bufnr)
    local wins = vim.fn.win_findbuf(bufnr)
    if #wins == 0 then
        return nil
    end
    local current_tab = vim.api.nvim_get_current_tabpage()
    local target = wins[1]
    for _, win in ipairs(wins) do
        if vim.api.nvim_win_get_tabpage(win) == current_tab then
            target = win
            break
        end
    end
    vim.api.nvim_set_current_win(target)
    return target
end

-- M.show(): summon the last finished query result (`<leader>qr`).
-- Called by: the `<leader>qr` mapping in nvim/lua/config/editor.lua
-- SQL: none (reads the recorded dadbod output file)
-- Args: none
-- Returns: the window id the result ended up in, or nil when a query is still
--   running / nothing was recorded / the output file is gone (each notifies)
-- Side effects: focuses an existing result window, or `:pedit`s the output
--   file back into the preview window, restores its drawer options (unlisted,
--   read-only, `bufhidden=delete` -- FR-018) and focuses it
function M.show()
    if slot.running then
        vim.notify('db_results: query still running', vim.log.levels.INFO)
        return nil
    end
    if not slot.outfile then
        vim.notify('db_results: no query result recorded yet', vim.log.levels.INFO)
        return nil
    end

    if slot.bufnr and slot.bufnr > 0 and vim.api.nvim_buf_is_valid(slot.bufnr) then
        return focus_win_for(slot.bufnr)
    end

    if vim.fn.filereadable(slot.outfile) == 1 then
        -- `:pedit` shows the result in the preview window but never moves the
        -- cursor into it (`:h preview-window`); focus it explicitly so summon
        -- lands the developer on the result.
        vim.cmd.pedit(vim.fn.fnameescape(slot.outfile))
        local bufnr = vim.fn.bufnr(slot.outfile)
        if bufnr > 0 then
            apply_drawer_options(bufnr)
        end
        return focus_win_for(bufnr) or vim.api.nvim_get_current_win()
    end

    vim.notify('db_results: output file no longer exists (' .. slot.outfile .. ')', vim.log.levels.WARN)
    return nil
end

return M
