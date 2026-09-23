-- Jump/toggle between the current code buffer and the database workspace
-- (dadbod-ui drawer + dadbod query/result buffers), usable from any tab.
--
-- `<leader>q` toggles: from code jumps into the DB workspace (drawer first,
-- then any buffer carrying `b:db`), from the DB workspace returns to the code
-- window that was active before the jump. If no DB window is open it opens the
-- drawer via `:DBUIToggle` and focuses it.
--
-- Neovim buffers are global (tabs only split the window layout), so dadbod
-- query buffers share the `:bnext`/`:bprev` cycle used by `<S-h>`/`<S-l>`.
-- This module gives an explicit, one-key route to the DB workspace instead of
-- relying on buffer cycling.

local M = {}

local previous_win = nil

local function has_db_context(bufnr)
    return vim.b[bufnr].db ~= nil
end

local function is_drawer(bufnr)
    return vim.bo[bufnr].filetype == 'dbui'
end

local function find_win(match)
    for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
        for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
            if match(vim.api.nvim_win_get_buf(winid)) then
                return winid
            end
        end
    end
    return nil
end

local function find_drawer()
    return find_win(is_drawer)
end

local function open_drawer()
    local ok, err = pcall(vim.cmd, 'DBUIToggle')
    if not ok then
        vim.notify('db_jump: DBUIToggle unavailable: ' .. tostring(err), vim.log.levels.WARN)
        return nil
    end
    return find_drawer()
end

function M.find()
    local drawer = find_drawer()
    if drawer then
        return drawer
    end
    return find_win(has_db_context)
end

function M.back()
    local target = previous_win
    previous_win = nil
    if target and vim.api.nvim_win_is_valid(target) then
        vim.api.nvim_set_current_win(target)
        return target
    end
    return nil
end

function M.jump()
    local current = vim.api.nvim_get_current_win()
    local current_buf = vim.api.nvim_win_get_buf(current)
    if is_drawer(current_buf) or has_db_context(current_buf) then
        local target = M.back()
        if not target then
            vim.notify('db_jump: already in the DB workspace; no code window was recorded', vim.log.levels.INFO)
        end
        return target
    end

    local target = M.find()
    if target then
        previous_win = current
        vim.api.nvim_set_current_win(target)
        return target
    end

    local drawer = open_drawer()
    if drawer then
        previous_win = current
        vim.api.nvim_set_current_win(drawer)
        return drawer
    end
    return nil
end

return M
