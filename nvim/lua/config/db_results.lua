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

local slot = { outfile = nil, bufnr = nil, running = false }

local setup_done = false

-- on_pre(): mark the latest query as still running.
-- Called by: the `User */DBExecutePre` autocmd registered in M.setup()
-- SQL: none
-- Args: none (autocmd callback)
-- Returns: nothing
-- Side effects: sets slot.running = true, which makes M.show() refuse to
--   summon a half-written result file
local function on_pre()
    slot.running = true
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

-- M.setup(): register the two dadbod query autocmds (idempotent).
-- Called by: nvim/plugin/database.lua at plugin source time
-- SQL: none
-- Args: none
-- Returns: nothing (a second call is a no-op via setup_done)
-- Side effects: creates the `User */DBExecutePre|Post` autocmds
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
