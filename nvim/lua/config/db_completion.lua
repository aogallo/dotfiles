-- Database completion gate (specs/archive/2026-10-06-001-db-completion-gate).
--
-- The provider contributed by kristijanhusak/vim-dadbod-completion runs
-- synchronously on every keystroke in a SQL buffer and, when the connection
-- fails, retries on the next keystroke too: its cache record for the buffer is
-- only written after db#connect() returns (research.md R-0001..R-0004). A dead
-- database therefore froze the editor on every character, and each attempt also
-- forced a full redraw and wrote "[dadbod completion] Connecting to db…" into
-- the message area (R-0006).
--
-- This module decides whether that provider is allowed to run at all. It keeps
-- a per-connection usability verdict and answers one question for the
-- completion engine: is this connection known usable right now?
--
-- Usability is established by a single deliberate pre-warm of the plugin's own
-- cache -- vim_dadbod_completion#fetch(), a public autoload function. Once
-- s:buffers[bufnr] exists, the provider's own retry guard is satisfied and the
-- db#connect on the typing path becomes unreachable, so suggestion generation
-- cannot connect (D-0003). The pre-warm runs from buffer open, from an explicit
-- refresh, or from a query the developer chose to run -- never from typing.
--
-- Nothing here is written to disk, no buffer is modified, and no other
-- completion source is touched.

local M = {}

local db_context = require 'config.db_context'

--------------------------------------------------------------------------------
-- State (data-model.md §1). All session-local; nothing is ever persisted.
--------------------------------------------------------------------------------

-- The developer's switch. Starting state is 'on' (FR-011).
local gate = { enabled = true, change_count = 0 }

-- connectionKey -> ConnectionState. This table is the memory that an attempt
-- already happened, which is what makes "at most one attempt per connection"
-- (FR-013) enforceable rather than aspirational.
--
--   state        = 'undetermined' | 'warming' | 'usable' | 'unusable'
--   attempted    = a determination has completed, either way
--   notice_shown = the automatic-disabling notice was already emitted
--   last_trigger = which trigger ran the last determination (diagnostic)
--   database     = the only form of this connection that may reach a message
local ledger = {}

-- bufnr -> { connection = connectionKey|nil, kind = 'query'|'dbui' }
--
-- Cached here so M.enabled() never has to read buffer state itself: the gate is
-- evaluated in fast-event contexts where such reads are not safe (R-0011).
local bindings = {}

-- In-flight guard, so two autocmds firing for one buffer cannot produce two
-- attempts. The determination itself runs inline: every trigger is already a
-- deliberate non-typing event, so deferring it would only add a window in which
-- the state could change underneath the caller.
local determination = { in_flight = false, trigger = nil, started_tick = nil }

local setup_done = false

--------------------------------------------------------------------------------
-- Identity (data-model.md §2)
--------------------------------------------------------------------------------

-- The connection key is the raw b:db string, and deliberately not a re-parsed
-- URL: a second parser here would be a second thing that can disagree with
-- db#connect(db#resolve(db)), which is the call being predicted. This repository
-- writes b:db from exactly one place (nvim/lua/config/db_query_buffer.lua:230),
-- so the string is canonical by construction and grouping needs no parsing.
--
-- Two strings differing only in a '#fragment' or query part would be tracked
-- separately. This repository never produces such a pair, and treating them as
-- distinct fails toward attempting rather than toward suppressing.
local function url_of(bufnr)
    local url = db_context.url_from_buffer(bufnr)
    if type(url) == 'string' and url ~= '' then
        return url
    end
    return nil
end

-- A DBUI buffer carries b:dbui_db_key_name, a registry key rather than a URL
-- (vim_dadbod_completion.vim:380-393). Resolve it through db-ui's own
-- connection info so DBUI buffers keep working; without this they would look
-- connection-less and lose completion entirely.
local function dbui_url_of(bufnr)
    local name = vim.b[bufnr].dbui_db_key_name
    if type(name) ~= 'string' or name == '' then
        return nil
    end
    local ok, dbui = pcall(require, 'db_ui')
    if not ok or type(dbui.get_conn_info) ~= 'function' then
        return nil
    end
    local info = dbui.get_conn_info(name)
    if type(info) ~= 'table' then
        return nil
    end
    for _, field in ipairs { 'conn', 'url' } do
        local value = info[field]
        if type(value) == 'string' and value ~= '' then
            return value
        end
    end
    return nil
end

-- A human label for a connection, derived once and cached. Only the database
-- name is ever used: a sybase:// URL carries a password, so rendering the URL
-- would leak credentials into the notification history (FR-029).
local function label_for(connection)
    local db = db_context.url_database(connection)
    if type(db) == 'string' and db ~= '' then
        return db
    end
    -- Non-sybase schemes have no database name to extract, and their URL may or
    -- may not carry a secret, so use a fixed phrase rather than guess at a safe
    -- rendering.
    return 'this connection'
end

local function entry_for(connection)
    local entry = ledger[connection]
    if not entry then
        entry = {
            state = 'undetermined',
            attempted = false,
            notice_shown = false,
            last_trigger = nil,
            database = label_for(connection),
        }
        ledger[connection] = entry
    end
    return entry
end

--------------------------------------------------------------------------------
-- Notices (contracts/db-completion-gate.md §3.4)
--------------------------------------------------------------------------------

local function notify(message)
    require('notifications').notify(message, vim.log.levels.WARN, { source = 'DB' })
end

-- The raw client error is deliberately withheld. db#systemlist is invoked with
-- an argv that carries the login (nvim/autoload/db/adapter/sybase.vim builds
-- -U/-P args), so an error message can quote the command it ran, and with it the
-- password. FR-019 asks for the database's own failure rather than a
-- completion-feature error; naming the database and saying it is unreachable
-- carries that meaning without the secret.
local function unavailable_message(entry)
    return string.format(
        'Could not reach %s — the database is unavailable. Schema completion stays off.',
        entry.database
    )
end

--------------------------------------------------------------------------------
-- Buffer bindings
--------------------------------------------------------------------------------

-- A SQL buffer with no connection is recorded with connection = nil, which is
-- how FR-003's case never reaches the provider at all. Previously such a buffer
-- re-ran a wasted fetch() on every keystroke (R-0005).
local function bind(bufnr)
    local binding = bindings[bufnr] or {}
    local dbui_url = dbui_url_of(bufnr)
    if dbui_url then
        binding.kind = 'dbui'
        binding.connection = dbui_url
    else
        binding.kind = 'query'
        binding.connection = url_of(bufnr)
    end
    bindings[bufnr] = binding
    return binding
end

local function unbind(bufnr)
    local binding = bindings[bufnr]
    if binding and binding.connection == nil then
        -- Nothing to forget: a buffer with no connection holds no verdict.
        return
    end
    -- The ledger entry is intentionally kept. A connection's verdict survives
    -- navigating away from it and back, so a second buffer on the same
    -- connection neither re-attempts nor re-notifies (FR-013).
    bindings[bufnr] = nil
end

--------------------------------------------------------------------------------
-- Determination (contracts/db-completion-gate.md §1)
--------------------------------------------------------------------------------

-- Establishes one connection's usability. Runs off the typing path by
-- construction: every caller is a deliberate event, and nothing in the gate or
-- the provider can reach it.
local function run_determination(bufnr, connection, trigger)
    local entry = entry_for(connection)
    entry.last_trigger = trigger
    entry.attempted = true

    -- pcall covers everything the pre-warm can raise. db#connect() throws on a
    -- failed client call (vim-dadbod/autoload/db.vim:372-375), and an error from
    -- anywhere else in the plugin's cache fill must not leave the entry stuck in
    -- 'warming' with the gate closed and nothing able to reopen it (FR-014).
    local ok = pcall(vim.api.nvim_buf_call, bufnr, function()
        vim.fn['vim_dadbod_completion#fetch'](bufnr)
    end)

    if ok then
        entry.state = 'usable'
        return
    end

    entry.state = 'unusable'
    if not entry.notice_shown then
        entry.notice_shown = true
        notify(unavailable_message(entry) .. ' Use :DBCompletionRefresh to try again.')
    end
end

--- M.determine(connection, trigger, bufnr): run one determination.
--- Not reachable from the gate or the provider, only from the deliberate
--- triggers below.
function M.determine(connection, trigger, bufnr)
    if type(connection) ~= 'string' or connection == '' or not bufnr then
        return
    end
    local entry = entry_for(connection)
    -- FR-013/FR-014: one attempt per connection, per session. Two deliberate
    -- triggers override it: :DBCompletionRefresh (FR-017), and a query the
    -- developer chose to run against a connection that already failed
    -- (FR-018/R-0024) -- the query_pre caller only asks when the state is
    -- 'unusable', so a healthy connection is never re-probed this way.
    if entry.attempted and trigger ~= 'refresh_command' and trigger ~= 'query_pre' then
        return
    end
    if determination.in_flight then
        return
    end

    -- 'warming' is visible to the gate for the duration of the client call, so a
    -- keystroke arriving during it still cannot reach the provider.
    entry.state = 'warming'
    determination.in_flight = true
    determination.trigger = trigger
    determination.started_tick = vim.loop.hrtime()

    local ok, err = pcall(run_determination, bufnr, connection, trigger)

    determination.in_flight = false
    determination.trigger = nil
    determination.started_tick = nil

    if not ok then
        -- run_determination is already pcall-guarded internally, so reaching
        -- here means the failure was in this module rather than in the database.
        -- Record it as unusable rather than leaving the entry unusable-to-recover.
        local entry_after = entry_for(connection)
        entry_after.state = 'unusable'
        entry_after.attempted = true
        notify('Schema completion disabled for ' .. entry_after.database .. ': ' .. tostring(err))
    end
end

--- M.maybe_determine(bufnr, trigger): the per-buffer decision.
--- Called from buffer open for query buffers. A connection already judged
--- usable or unusable is left alone, so opening more buffers on it neither
--- re-attempts nor re-notifies.
local function maybe_determine(bufnr, trigger)
    local binding = bindings[bufnr]
    if not binding or not binding.connection then
        return
    end
    M.determine(binding.connection, trigger, bufnr)
end

--------------------------------------------------------------------------------
-- The gate (contracts/db-completion-gate.md §2)
--------------------------------------------------------------------------------

--- M.enabled(): the gate, called by blink.cmp on every completion request.
---
--- Returns true only when the switch is on AND the current buffer's connection
--- has been positively established as usable. 'undetermined' and 'warming' are
--- both closed, which is what stops the retry loop from recurring: the gate can
--- never open while the connection is still unknown (FR-016).
---
--- No I/O and no client call, ever -- if this function could block, the defect
--- would be unfixed.
---@return boolean
function M.enabled()
    if vim.in_fast_event() then
        return false
    end
    if not gate.enabled then
        return false
    end
    local bufnr = vim.api.nvim_get_current_buf()
    local binding = bindings[bufnr]
    if not binding or not binding.connection then
        return false
    end
    local entry = ledger[binding.connection]
    if not entry then
        return false
    end
    return entry.state == 'usable'
end

--------------------------------------------------------------------------------
-- Developer-facing actions
--------------------------------------------------------------------------------

local function state_label()
    return gate.enabled and 'on' or 'off'
end

-- A keymap description is captured when the keymap is set, so the label can
-- only track the switch by re-registering the binding on every change
-- (research.md R-0031).
local function relabel()
    pcall(function()
        require('which-key').add {
            {
                '<leader>qc',
                desc = 'database: DB completion (' .. state_label() .. ')',
            },
        }
    end)
end

--- M.toggle(): the switch (FR-008, FR-011). Touches no connection state, cancels
--- no in-flight determination, and starts no determination.
function M.toggle()
    gate.enabled = not gate.enabled
    gate.change_count = gate.change_count + 1
    notify('Database completion ' .. state_label() .. ' (<leader>qc)')
    relabel()
end

--- M.refresh(): the explicit recovery action (FR-017). Always attempts, even
--- for a connection that already failed, and never touches the buffer.
function M.refresh()
    local bufnr = vim.api.nvim_get_current_buf()
    local binding = bind(bufnr)
    if not binding.connection then
        notify 'No database connection is bound to this buffer.'
        return
    end

    local entry = entry_for(binding.connection)
    entry.notice_shown = true -- an explicit attempt is not the silent one
    M.determine(binding.connection, 'refresh_command', bufnr)

    -- Report a still-unreachable connection immediately rather than only when
    -- the queued attempt settles, so the developer gets one answer per press.
    if entry.attempted and entry.state == 'unusable' then
        notify(unavailable_message(entry))
    end
end

--------------------------------------------------------------------------------
-- Wiring
--------------------------------------------------------------------------------

local function is_sql(bufnr)
    local ft = vim.bo[bufnr].filetype
    return ft == 'sql' or ft == 'mysql' or ft == 'plsql'
end

function M.setup()
    if setup_done then
        return
    end
    setup_done = true

    vim.api.nvim_create_autocmd({ 'FileType', 'BufEnter' }, {
        callback = function(args)
            local bufnr = args.buf
            if not vim.api.nvim_buf_is_valid(bufnr) then
                return
            end
            if not is_sql(bufnr) and vim.b[bufnr].dbui_db_key_name == nil then
                -- Not a buffer this feature has any opinion about. Drop any stale
                -- binding so a SQL buffer that lost its connection stops being
                -- treated as one.
                unbind(bufnr)
                return
            end
            bind(bufnr)
            maybe_determine(bufnr, 'buffer_open')
        end,
    })

    -- Recovery route 2: the developer chose to run a query against this
    -- connection, so one determination is expected. Neither DBExecutePre nor
    -- DBExecutePost carries a success verdict (research.md R-0024), so the
    -- determination's own db#connect is the verdict -- which is what yields
    -- FR-018 and FR-019 from one mechanism. Only an already-failed connection is
    -- re-probed; a healthy one is left alone.
    vim.api.nvim_create_autocmd('User', {
        pattern = '*/DBExecutePre',
        callback = function()
            local bufnr = vim.api.nvim_get_current_buf()
            local binding = bindings[bufnr]
            if not binding or not binding.connection then
                bind(bufnr)
                binding = bindings[bufnr]
            end
            if not binding or not binding.connection then
                return
            end
            local entry = entry_for(binding.connection)
            if entry.state == 'unusable' then
                entry.notice_shown = true
                M.determine(binding.connection, 'query_pre', bufnr)
            end
        end,
    })

    relabel()
end

--------------------------------------------------------------------------------
-- Test seams
--
-- The smoke tests need to drive the state machine without a running event loop
-- or a real completion request. These expose the internal steps the autocmds
-- use; they add no behaviour of their own.
--------------------------------------------------------------------------------

--- Test seam: bind a buffer's connection without triggering a determination.
--- Mirrors the bookkeeping half of the FileType/BufEnter autocmd.
function M._bind(bufnr)
    bind(bufnr)
    return bindings[bufnr]
end

--- Test seam: the full buffer-open path -- bind, then determine if warranted.
function M._open(bufnr)
    bind(bufnr)
    maybe_determine(bufnr, 'buffer_open')
    return bindings[bufnr]
end

function M._force(connection, state)
    entry_for(connection).state = state
end

function M._state(connection)
    local entry = ledger[connection]
    return entry and entry.state or nil
end

function M._set_enabled(value)
    gate.enabled = value
end

M._ledger = ledger
M._bindings = bindings
M._gate = gate

return M
