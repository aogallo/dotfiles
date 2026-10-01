-- Buffer-visibility guard: keep a tab in the buffer row for every buffer the
-- developer deliberately opened (specs/011-query-buffer-tab-visibility,
-- issue #96; FR-001).
--
-- Why this module exists. `:bdelete` clears 'buflisted', and bufferline renders
-- only buffers with `listed == 1` (bufferline.nvim utils/init.lua:150) while
-- exposing no option to relax that. Bringing a buffer back does not undo the
-- close: `:buffer N`, `:bnext` and `nvim_set_current_buf` leave it unlisted, so
-- a query buffer the developer closes and later reopens has no tab, no close
-- icon, and nothing to return to (R-0001). Only `:edit <name>` and fzf-lua's
-- explicit workaround re-list it — that route-dependence is the reported
-- "for some reason".
--
-- Design constraints, all deliberate (R-0002, R-0003):
--
--   * ADDITIVE ONLY. The only write this module performs is
--     'buflisted': false -> true. It never unlists, unloads, wipes or deletes
--     anything, ever. The buffer list is also the close-action's work list
--     (snacks/bufdelete.lua:37-41 iterates `if vim.bo[b].buflisted`), so any
--     unlisting would remove buffers from the set the developer can close, and
--     any bulk re-listing could resurrect work deliberately closed
--     (FR-021, FR-022, FR-023).
--   * NOT A LIST SYNC. There is deliberately no routine that makes the buffer
--     list match what is displayed. Symmetry would let a window switch close or
--     revive a buffer as a side effect.
--   * NO `BufAdd` LISTENER. Re-listing fires 'BufAdd' (measured), so listening
--     for it is re-entrancy for no coverage gain. The tab appears on the next
--     redraw anyway: bufferline sets `vim.o.tabline` to a redraw-time expression
--     (bufferline.lua:205), so no refresh call is needed and the guard never
--     asks for one.
--   * NO `BufReadPost`/`BufNewFile`. Those never fire for an existing buffer
--     being revisited, which is precisely the reported case.
--   * NO `BufWinLeave`/`BufDelete`. There is no window at that point to show a
--     tab in.
--
-- Generated output is excluded (FR-018): a result buffer over a `.dbout` file,
-- any buffer with a non-empty 'buftype' (DBUI drawer, quickfix, help, prompt),
-- and any buffer that opts out explicitly. Membership is decided by intent,
-- never by the buffer's current read-only/unmodified/unloaded/unlisted state —
-- those are states, not intents (R-0009). The opt-out flag below is the
-- extension point for a future generated buffer matching neither rule; name it
-- consistently here and in nvim/README.md.
--
-- This module is editor-level and knows nothing about databases, so the tab
-- exists for any developer-opened buffer and Neovim stays usable with no
-- database loaded (FR-026). It must not require any database module.
--
-- The tabline cost is one 'buflisted' read per buffer entry in the common case
-- (already listed -> return immediately), which is why four events are
-- affordable: `BufEnter` covers the reported routes, `BufWinEnter` covers a
-- buffer displayed by a split without `BufEnter` firing in the caller's
-- context, `TabEnter` covers tab-local entry, and `VimEnter` covers buffers
-- passed on the command line.
--
-- DOCUMENTATION CONVENTION (see nvim/README.md, "Documenting a function"):
--   every function below carries a header with Purpose / Called by / SQL /
--   Args / Returns / Side effects. Required for new functions too.

local M = {}

local AUGROUP = 'aogallo/buffer_visibility'

-- Set on the query buffers this module must leave alone: a buffer-local flag, so
-- opting out is per buffer and needs no central registry (data-model.md §5).
local OPT_OUT_FLAG = 'aogallo_no_tab'

local setup_done = false

-- Handlers invoked after this module re-lists a buffer, in registration order.
local reopen_handlers = {}

-- is_valid(bufnr): whether bufnr is a buffer that can still be inspected.
-- Called by: ensure_listed()
-- SQL: none
-- Args: bufnr = buffer number
-- Returns: true when the buffer is valid
-- Side effects: none
local function is_valid(bufnr)
    return type(bufnr) == 'number' and bufnr > 0 and vim.api.nvim_buf_is_valid(bufnr)
end

-- M.is_generated_output(bufnr) -> boolean
-- Purpose: decide whether a buffer belongs to the generated-output class, which
--   must never gain a tab (FR-018, data-model.md §5).
-- Called by: ensure_listed(); safe to call from tests without an editor setup
-- SQL: none
-- Args: bufnr = buffer number
-- Returns: true for a name ending in `.dbout`, a non-empty 'buftype', or a
--   buffer that set the opt-out flag; false otherwise
-- Side effects: none — a pure predicate
function M.is_generated_output(bufnr)
    if not is_valid(bufnr) then
        return false
    end
    if vim.api.nvim_buf_get_name(bufnr):lower():sub(-6) == '.dbout' then
        return true
    end
    local bo = vim.bo[bufnr]
    if bo.buftype ~= '' then
        return true
    end
    return vim.b[bufnr][OPT_OUT_FLAG] == true
end

-- M.register_reopen_handler(fn)
-- Purpose: let an owning module restore its own buffer state once this module
--   has re-listed a buffer (contract §1.3).
-- Called by: db_query_buffer.setup()
-- SQL: none
-- Args: fn = function(bufnr), called only on the re-list path, never on the
--   already-listed no-op path and never for generated output
-- Returns: nothing
-- Side effects: appends to the handler list; effective immediately, including
--   when registered after M.setup()
function M.register_reopen_handler(fn)
    if type(fn) == 'function' then
        table.insert(reopen_handlers, fn)
    end
end

-- run_reopen_handlers(bufnr): notify every registered handler that bufnr was
--   re-listed by this module.
-- Called by: ensure_listed(), after the listing write succeeds
-- SQL: none
-- Args: bufnr = buffer number
-- Returns: nothing
-- Side effects: runs each handler in registration order. A handler that throws
--   is isolated with pcall: one broken handler must not stop the others, nor
--   propagate an error out of an autocmd callback (contract §1.3).
local function run_reopen_handlers(bufnr)
    for _, handler in ipairs(reopen_handlers) do
        pcall(handler, bufnr)
    end
end

-- ensure_listed(bufnr): give bufnr its tab back if it deserves one.
-- Purpose: the single state change this feature performs on a buffer
--   (data-model.md §4).
-- Called by: the autocmd callback registered in M.setup()
-- SQL: none
-- Args: bufnr = buffer number
-- Returns: nothing
-- Side effects: at most one option write, 'buflisted' false -> true, on a
--   buffer that is valid, displayed in a window, and currently unlisted. Never
--   writes true -> false, never unloads/wipes/deletes, emits no message and
--   defines no user command (I-1..I-6).
local function ensure_listed(bufnr)
    -- Cheap early return: the common case is an already-listed buffer, and this
    -- costs one option read (I-2, I-5).
    if not is_valid(bufnr) then
        return
    end
    if vim.bo[bufnr].buflisted then
        return
    end
    -- A tab is only meaningful for a buffer the developer is looking at.
    if #vim.fn.win_findbuf(bufnr) == 0 then
        return
    end
    -- Generated output takes no tab, in any path (I-4, FR-018).
    if M.is_generated_output(bufnr) then
        return
    end

    -- The single write in this module, and the only direction it ever writes in
    -- (I-3, FR-021, FR-022). This module NEVER unlists a buffer and NEVER calls
    -- `:bdelete`, `:bwipeout` or `:bunload` -- do not add such a path, and do not
    -- add a symmetric routine that lists or unlists on window/tab switch. The
    -- routine that spec rejected lived here (contract §5): closing is final, and
    -- only an explicit reopen brings a buffer back.
    vim.bo[bufnr].buflisted = true
    run_reopen_handlers(bufnr)
end

-- on_event(args): autocmd callback for the four entry events.
-- Called by: the autocmds registered in M.setup()
-- SQL: none
-- Args: args = autocmd callback arguments; args.buf is the entered buffer
-- Returns: nothing
-- Side effects: delegates to ensure_listed(args.buf)
local function on_event(args)
    ensure_listed(args.buf)
end

-- M.setup(): register the entry autocmds (idempotent).
-- Purpose: make the guard live for every developer-opened buffer, including
--   with no database loaded.
-- Called by: nvim/plugin/editor.lua at plugin source time (contract §1.1)
-- SQL: none
-- Args: none
-- Returns: nothing (a second call is a no-op via setup_done)
-- Side effects: creates the cleared augroup and registers BufEnter,
--   BufWinEnter, TabEnter and VimEnter at pattern '*'
function M.setup()
    if setup_done then
        return
    end
    setup_done = true
    vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWinEnter', 'TabEnter', 'VimEnter' }, {
        group = vim.api.nvim_create_augroup(AUGROUP, { clear = true }),
        pattern = '*',
        callback = on_event,
        desc = 'buffers: restore the tab of a displayed developer-opened buffer',
    })
end

return M
