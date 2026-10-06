-- Toggle and recovery smoke test (specs/archive/2026-10-06-001-db-completion-gate,
-- quickstart.md §3).
--
-- Covers User Story 2 (the switch and its visible state) and User Story 4 (both
-- recovery routes), plus the notice discipline User Story 3 depends on.
--
-- Same client harness as db_completion_smoke.lua: no autoload file is
-- shadowed. The fake sqsh/isql append one line to a counter file and exit 0 or
-- 1 according to a mode file, so db#connect() and the table listing run exactly
-- as shipped and every client invocation is countable. Mode 'fail' is "the
-- client cannot reach the server", which is how dadbod reports a dead database
-- (db#connect throws 'DB exec error'). No database server.
-- Exits with code 1 via :cquit on any assertion failure.

local function fail(ok, name, got, want)
    if ok then
        vim.print('PASS ' .. name)
        return
    end
    vim.print('FAIL ' .. name)
    vim.print('  got:  ' .. vim.inspect(got))
    vim.print('  want: ' .. vim.inspect(want))
    vim.cmd 'cquit'
end

--------------------------------------------------------------------------------
-- Harness (shared shape with db_completion_smoke.lua)
--------------------------------------------------------------------------------

local this_file = debug.getinfo(1, 'S').source:sub(2)
local module_root = vim.fn.fnamemodify(this_file, ':h:h:h')
vim.opt.rtp:prepend(module_root)

local real_db = vim.api.nvim_get_runtime_file('autoload/db.vim', false)
if #real_db == 0 then
    vim.print 'FAIL: vim-dadbod autoload/db.vim not on runtimepath'
    vim.cmd 'cquit'
end

local base = vim.fn.tempname()
vim.fn.mkdir(base .. '/bin', 'p')
local count_file = base .. '/count'
local mode_file = base .. '/mode'
vim.fn.writefile({}, count_file)
vim.fn.writefile({ 'tables' }, mode_file)
vim.env.DB_SMOKE_COUNT = count_file
vim.env.DB_SMOKE_MODE = mode_file

local client_script = {
    '#!/bin/sh',
    'printf "x\\n" >> "$DB_SMOKE_COUNT"',
    'mode=$(cat "$DB_SMOKE_MODE" 2>/dev/null)',
    'if [ "$mode" = "fail" ]; then',
    '  echo "sqsh: Unable to connect to server"',
    '  exit 1',
    'fi',
    'echo "mytable"',
    'exit 0',
}
for _, name in ipairs { 'sqsh', 'isql' } do
    vim.fn.writefile(client_script, base .. '/bin/' .. name)
    os.execute('chmod +x ' .. base .. '/bin/' .. name)
end
vim.env.PATH = base .. '/bin:' .. vim.env.PATH
vim.opt.rtp:prepend(base)

local function stub_count()
    return #vim.fn.readfile(count_file)
end

local function stub_set(mode)
    vim.fn.writefile({ mode }, mode_file)
end

--------------------------------------------------------------------------------
-- Notification capture
--------------------------------------------------------------------------------

local notices = {}
local real_notify = require('notifications').notify
require('notifications').notify = function(message)
    notices[#notices + 1] = message
end

local function notices_matching(pattern)
    local found = {}
    for _, message in ipairs(notices) do
        if message:find(pattern) then
            found[#found + 1] = message
        end
    end
    return found
end

local function reset_notices()
    notices = {}
end

--------------------------------------------------------------------------------
-- Fixtures
--------------------------------------------------------------------------------

local gate = require 'config.db_completion'

local down = 'sybase://u:p@down:5000/toggle_down_db'
local back = 'sybase://u:p@back:5000/toggle_back_db'
local other = 'sybase://u:p@other:5000/toggle_other_db'

local function sql_buffer(url)
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(bufnr, 'scratch:' .. bufnr .. '.sql')
    vim.api.nvim_set_current_buf(bufnr)
    vim.bo[bufnr].filetype = 'sql'
    -- b:db is assigned last, on purpose: the upstream plugin's own FileType
    -- fetch and the gate's autocmds both fire on FileType/BufEnter, and with no
    -- connection visible then neither attempts anything, so each case reaches
    -- its first determination through the seam it means to exercise.
    if url then
        vim.b[bufnr].db = url
    end
    return bufnr
end

--------------------------------------------------------------------------------
-- T018 — toggling is reversible and announces itself exactly once per press
--------------------------------------------------------------------------------

vim.print '--- T018: toggle reversibility ---'

do
    gate._set_enabled(true)
    local start_count = gate._gate.change_count
    reset_notices()

    gate.toggle()
    local off_notices = #notices
    fail(off_notices == 1, 'one notice per toggle', off_notices, 1)
    fail(gate._gate.enabled == false, 'switch is off', gate._gate.enabled, false)
    fail(notices[1]:find 'off' ~= nil, 'notice says which state it is now', notices[1], 'contains "off"')

    gate.toggle()
    fail(#notices == 2, 'two notices after two presses', #notices, 2)
    fail(gate._gate.enabled == true, 'starting state restored', gate._gate.enabled, true)
    fail(gate._gate.change_count == start_count + 2, 'one change per press', gate._gate.change_count - start_count, 2)

    -- No notice may leak a URL.
    local leaked = false
    for _, message in ipairs(notices) do
        if message:find 'sybase://' or message:find 'u:p@' then
            leaked = true
        end
    end
    fail(leaked == false, 'no toggle notice contains a URL', leaked, false)
end

--------------------------------------------------------------------------------
-- T020 — the switch closes the gate for every connection, and spares the rest
--------------------------------------------------------------------------------

vim.print '--- T020: switch scope ---'

do
    stub_set 'tables'
    local healthy = sql_buffer(other)
    gate._open(healthy)
    fail(gate._state(other) == 'usable', 'healthy connection usable', gate._state(other), 'usable')
    fail(gate.enabled() == true, 'gate open for the healthy connection', gate.enabled(), true)

    gate._set_enabled(false)
    fail(gate.enabled() == false, 'switch off closes the gate', gate.enabled(), false)

    -- A second connection is unaffected by the first one's switch: the switch is
    -- global, and the verdict for another connection is still 'usable'.
    gate._set_enabled(true)
    local second = sql_buffer 'sybase://u:p@second:5000/toggle_second_db'
    gate._open(second)
    fail(
        gate._state 'sybase://u:p@second:5000/toggle_second_db' == 'usable',
        'second connection usable',
        gate._state 'sybase://u:p@second:5000/toggle_second_db',
        'usable'
    )
    fail(gate.enabled() == true, 'gate open again', gate.enabled(), true)

    -- FR-005: the switch touches no connection state.
    fail(gate._state(other) == 'usable', 'switch left the ledger untouched', gate._state(other), 'usable')
end

--------------------------------------------------------------------------------
-- T019 — the keymap label tracks the live state
--------------------------------------------------------------------------------

vim.print '--- T019: label tracks state ---'

do
    -- Re-registration goes through which-key, which is not on the runtimepath in
    -- this headless session -- db_completion wraps the require in a pcall, so a
    -- missing plugin is correctly tolerated rather than reported. Inject a stand
    -- -in to observe what the module asks for: the description must carry the
    -- live state, and must change when the state changes (FR-009, R-0031).
    local registered = {}
    package.loaded['which-key'] = {
        add = function(specs)
            for _, spec in ipairs(specs) do
                -- which-key takes the lhs as the first element with the options
                -- beside it, the same shape as the existing
                -- { '<leader>b', group = 'buffers' } registration.
                if spec[1] == '<leader>qc' and spec.desc then
                    registered[#registered + 1] = spec.desc
                end
            end
        end,
    }

    reset_notices()
    gate._set_enabled(true)
    gate.toggle()
    gate.toggle()
    package.loaded['which-key'] = nil

    local saw_on = false
    local saw_off = false
    for _, desc in ipairs(registered) do
        if desc:find('(on)', 1, true) then
            saw_on = true
        end
        if desc:find('(off)', 1, true) then
            saw_off = true
        end
    end
    fail(saw_off == true, 'label showed (off) while off', saw_off, true)
    fail(saw_on == true, 'label showed (on) after toggling back', saw_on, true)
    fail(registered[1]:find 'database:' ~= nil, 'label names its group', registered[1], 'contains "database:"')
end

--------------------------------------------------------------------------------
-- T029 / T030 / T032 — the explicit recovery route
--------------------------------------------------------------------------------

vim.print '--- T029/T030: DBCompletionRefresh ---'

do
    -- A connection that fails, then comes back.
    stub_set 'fail'
    local bufnr = sql_buffer(down)
    gate._open(bufnr)
    fail(gate._state(down) == 'unusable', 'connection starts unusable', gate._state(down), 'unusable')
    fail(gate.enabled() == false, 'gate closed while down', gate.enabled(), false)

    -- The database is back: an explicit refresh must attempt again even though
    -- the connection was already judged (FR-017 overrides the one-attempt rule).
    stub_set 'tables'
    local attempts_before = stub_count()
    gate.refresh()
    fail(gate._state(down) == 'usable', 'refresh reopened the connection', gate._state(down), 'usable')
    fail(gate.enabled() == true, 'gate open after refresh', gate.enabled(), true)
    fail(stub_count() > attempts_before, 'refresh made a new attempt', stub_count() > attempts_before, true)
end

do
    -- Still down: the refresh stays closed, attempts once, and says so once.
    stub_set 'fail'
    local bufnr = sql_buffer 'sybase://u:p@still:5000/toggle_still_db'
    gate._open(bufnr)
    fail(
        gate._state 'sybase://u:p@still:5000/toggle_still_db' == 'unusable',
        'connection unusable',
        gate._state 'sybase://u:p@still:5000/toggle_still_db',
        'unusable'
    )

    reset_notices()
    local attempts_before = stub_count()
    gate.refresh()
    fail(
        gate._state 'sybase://u:p@still:5000/toggle_still_db' == 'unusable',
        'still unusable after refresh',
        gate._state 'sybase://u:p@still:5000/toggle_still_db',
        'unusable'
    )
    fail(stub_count() == attempts_before + 1, 'refresh attempted exactly once', stub_count() - attempts_before, 1)

    local failures = notices_matching 'unavailable'
    fail(#failures == 1, 'the still-down failure is reported once', #failures, 1)

    -- FR-019: reported as the database's own unavailability, not as a
    -- completion-feature error, and with no client error text (which can quote
    -- an argv carrying the login).
    local framed_wrongly = false
    for _, message in ipairs(failures) do
        if message:lower():find 'completion error' or message:find 'stack traceback' then
            framed_wrongly = true
        end
    end
    fail(framed_wrongly == false, 'failure framed as the database, not the feature', framed_wrongly, false)
    local named = false
    for _, message in ipairs(failures) do
        if message:find 'toggle_still_db' then
            named = true
        end
    end
    fail(named == true, 'failure names the database', named, true)
end

do
    -- FR-017 edge: a buffer with no connection gets a notice and no attempt.
    local bare = sql_buffer(nil)
    reset_notices()
    local attempts_before = stub_count()
    gate.refresh()
    fail(#notices == 1, 'one notice for an unbound buffer', #notices, 1)
    fail(stub_count() == attempts_before, 'no attempt for an unbound buffer', stub_count() - attempts_before, 0)
    fail(gate.enabled() == false, 'gate stays closed', gate.enabled(), false)
    local _ = bare
end

--------------------------------------------------------------------------------
-- T031 / T033 — the query-triggered recovery route
--------------------------------------------------------------------------------

vim.print '--- T031: DBExecutePre recovery ---'

do
    -- dadbod fires `User <output>.dbout/DBExecutePre` (autoload/db.vim,
    -- s:filter_write), which is the shape the module's `*/DBExecutePre` pattern
    -- matches; the bare event name would match nothing.
    local query_event = vim.fn.tempname() .. '.dbout/DBExecutePre'

    -- Down, then the developer runs a query against it: one re-determination.
    stub_set 'fail'
    local bufnr = sql_buffer 'sybase://u:p@query:5000/toggle_query_db'
    local connection = 'sybase://u:p@query:5000/toggle_query_db'
    gate._open(bufnr)
    fail(gate._state(connection) == 'unusable', 'connection unusable', gate._state(connection), 'unusable')

    -- Still down: the query route attempts once and stays closed.
    local attempts_before = stub_count()
    vim.api.nvim_exec_autocmds('User', { pattern = query_event, modeline = false })
    fail(stub_count() == attempts_before + 1, 'query route attempted exactly once', stub_count() - attempts_before, 1)

    -- Back up: the next query re-establishes it without any other action.
    stub_set 'tables'
    local before_ok = stub_count()
    vim.api.nvim_exec_autocmds('User', { pattern = query_event, modeline = false })
    fail(gate._state(connection) == 'usable', 'query route reopened the connection', gate._state(connection), 'usable')
    fail(stub_count() > before_ok, 'query route made a new attempt', stub_count() > before_ok, true)

    -- A healthy connection is never re-probed by a query (FR-018 bounds the
    -- recovery to connections that actually failed).
    local settled = stub_count()
    vim.api.nvim_exec_autocmds('User', { pattern = query_event, modeline = false })
    fail(stub_count() == settled, 'healthy connection is not re-probed', stub_count() - settled, 0)
end

--------------------------------------------------------------------------------
-- FR-020 — a recovery action changes no buffer state
--------------------------------------------------------------------------------

vim.print '--- buffer untouched by toggle/refresh ---'
do
    local bufnr = sql_buffer(back)
    local text = { 'select count(*) from t' }
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, text)
    local db_before = vim.b[bufnr].db

    gate._set_enabled(true)
    gate.toggle()
    gate.toggle()
    gate.refresh()

    fail(
        vim.deep_equal(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), text),
        'buffer text unchanged by toggle and refresh',
        vim.api.nvim_buf_get_lines(bufnr, 0, -1, false),
        text
    )
    fail(vim.b[bufnr].db == db_before, 'b:db unchanged', vim.b[bufnr].db, db_before)
    fail(vim.bo[bufnr].filetype == 'sql', 'filetype unchanged', vim.bo[bufnr].filetype, 'sql')
end

require('notifications').notify = real_notify
vim.print 'ALL db_completion_toggle_smoke ASSERTIONS PASSED'
