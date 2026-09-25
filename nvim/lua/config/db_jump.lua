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
--
-- DOCUMENTATION CONVENTION (see nvim/README.md, "Documenting a function"):
--   every function carries a header with Purpose / Called by / SQL / Args /
--   Returns / Side effects. Required for new functions too.

local M = {}

local previous_win = nil

-- has_db_context(bufnr): is this buffer a dadbod/query buffer?
-- Called by: find_win() (via M.find()) and M.jump()
-- SQL: none
-- Args: bufnr = buffer number
-- Returns: boolean — true when the buffer carries a b:db context
-- Side effects: none
local function has_db_context(bufnr)
    return vim.b[bufnr].db ~= nil
end

-- is_drawer(bufnr): is this buffer the DBUI drawer?
-- Called by: find_drawer() and M.jump()
-- SQL: none
-- Args: bufnr = buffer number
-- Returns: boolean — true when filetype=dbui
-- Side effects: none
local function is_drawer(bufnr)
    return vim.bo[bufnr].filetype == 'dbui'
end

-- find_win(match): first window in any tab whose buffer matches.
-- Called by: find_drawer(), M.find()
-- SQL: none
-- Args: match = function(bufnr) -> boolean
-- Returns: window id, or nil when no window matches (search order: current tab
--   first, so the nearest drawer wins)
-- Side effects: none
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

-- find_drawer(): locate the DBUI drawer window.
-- Called by: open_drawer(), M.find()
-- SQL: none
-- Args: none
-- Returns: window id, or nil when the drawer is not open anywhere
-- Side effects: none
local function find_drawer()
    return find_win(is_drawer)
end

-- open_drawer(): open the DBUI drawer and locate it.
-- Called by: M.jump() when no DB window was found
-- SQL: none (runs dadbod-ui's :DBUIToggle)
-- Args: none
-- Returns: drawer window id, or nil when :DBUIToggle failed (notifies with the
--   error text)
-- Side effects: may open the drawer window
local function open_drawer()
    local ok, err = pcall(vim.cmd, 'DBUIToggle')
    if not ok then
        vim.notify('db_jump: DBUIToggle unavailable: ' .. tostring(err), vim.log.levels.WARN)
        return nil
    end
    return find_drawer()
end

-- M.find(): find any DB workspace window without focusing it.
-- Called by: M.jump(); exposed for tests and for callers that only need the id
-- SQL: none
-- Args: none
-- Returns: window id of the drawer, else of the first b:db buffer, else nil
-- Side effects: none
function M.find()
    local drawer = find_drawer()
    if drawer then
        return drawer
    end
    return find_win(has_db_context)
end

-- M.back(): return to the code window recorded by the last M.jump() out.
-- Called by: M.jump() when the current window is already DB workspace
-- SQL: none
-- Args: none
-- Returns: window id focused, or nil when nothing was recorded / it is gone
-- Side effects: clears the recorded window (one-shot) and focuses the target
function M.back()
    local target = previous_win
    previous_win = nil
    if target and vim.api.nvim_win_is_valid(target) then
        vim.api.nvim_set_current_win(target)
        return target
    end
    return nil
end

-- M.jump(): toggle between the code buffer and the DB workspace (`<leader>qj`).
-- Called by: the `<leader>qj` mapping in nvim/lua/config/editor.lua
-- SQL: none (at most dadbod-ui's :DBUIToggle)
-- Args: none
-- Returns: the window id now focused, or nil when the toggle found nothing to
--   do (e.g. already in the workspace with no recorded code window — notifies)
-- Side effects: records the pre-jump window, moves the current window, and may
--   open the drawer
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
