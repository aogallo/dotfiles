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

local M = {}

local slot = { outfile = nil, bufnr = nil, running = false }

local setup_done = false

local function on_pre()
    slot.running = true
end

local function on_post(args)
    slot.outfile = vim.fn.fnamemodify(args.match, ':h')
    slot.bufnr = vim.fn.bufnr(slot.outfile)
    slot.running = false
end

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
        return focus_win_for(vim.fn.bufnr(slot.outfile)) or vim.api.nvim_get_current_win()
    end

    vim.notify('db_results: output file no longer exists (' .. slot.outfile .. ')', vim.log.levels.WARN)
    return nil
end

return M
