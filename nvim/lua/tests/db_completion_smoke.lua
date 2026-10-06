-- Gate smoke test (specs/archive/2026-10-06-001-db-completion-gate, quickstart.md §1).
--
-- The guarantee under test is that suggestion generation cannot reach the
-- database. The most direct way to measure that is to count how often the
-- provider is consulted at all, so this harness shadows
-- vim_dadbod_completion#omni with a counting override and models what blink.cmp
-- does on each keystroke: ask the gate, and only call the provider if it says
-- yes.
--
-- That gives a differential rather than a vacuous zero -- the healthy-connection
-- control proves the harness really does reach the provider when the gate is
-- open, so a zero in the broken-connection case means the gate, not a broken
-- measurement (SC-002, SC-010, SC-011).
--
-- No autoload file is shadowed. The two client binaries the Sybase adapter can
-- use (sqsh, isql) are replaced by a script that appends one line to a counter
-- file and exits 0 or 1 according to a mode file, so db#connect() and the table
-- listing run exactly as shipped and every client invocation is countable.
--
-- The modes follow dadbod's own contract instead of inventing a failure it does
-- not have: db#systemlist() never raises -- it returns [] on a non-zero exit
-- (autoload/db.vim) -- and the failure a developer sees comes from db#connect()
-- throwing 'DB exec error'. Mode 'fail' therefore means "the client cannot
-- reach the server", which is the reported defect; mode 'ok' is a healthy
-- connection; mode 'empty' is a healthy connection whose listing comes back
-- empty, which FR-016 says is not a verdict.
--
-- Removing the client from PATH reproduces the other half of the report: the
-- adapter's executable check fails inside db#connect(), so an ungated buffer
-- raises on every keystroke before anything is written (research.md R-0004).
--
-- No database server and no real client binary are involved.
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
-- Harness
--------------------------------------------------------------------------------

-- A `-u NORC` session does not have this repository on its runtimepath, so the
-- Sybase adapter (nvim/autoload/db/adapter/sybase.vim) would be missing and
-- db#connect would fail for the wrong reason. Derive the module root from this
-- file's own location rather than assuming a working directory.
local this_file = debug.getinfo(1, 'S').source:sub(2)
local module_root = vim.fn.fnamemodify(this_file, ':h:h:h')
vim.opt.rtp:prepend(module_root)

local real_db = vim.api.nvim_get_runtime_file('autoload/db.vim', false)
local real_completion = vim.api.nvim_get_runtime_file('autoload/vim_dadbod_completion.vim', false)
if #real_db == 0 or #real_completion == 0 then
    vim.print 'FAIL: vim-dadbod plugins not on runtimepath'
    vim.cmd 'cquit'
end

-- The fake client: one line per invocation in $DB_SMOKE_COUNT, exit status
-- from $DB_SMOKE_MODE. db#connect() runs it through the adapter's input()
-- argv, and the table listing runs it through db#systemlist(), so both paths
-- are counted by the same file.
local base = vim.fn.tempname()
vim.fn.mkdir(base .. '/bin', 'p')
local count_file = base .. '/count'
local mode_file = base .. '/mode'
vim.fn.writefile({}, count_file)
vim.fn.writefile({ 'ok' }, mode_file)
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
    'if [ "$mode" = "empty" ]; then',
    '  exit 0',
    'fi',
    'echo "mytable"',
    'exit 0',
}
for _, name in ipairs { 'sqsh', 'isql' } do
    vim.fn.writefile(client_script, base .. '/bin/' .. name)
    os.execute('chmod +x ' .. base .. '/bin/' .. name)
end
vim.opt.rtp:prepend(base)

local function client_calls()
    return #vim.fn.readfile(count_file)
end

local function stub_set(mode)
    vim.fn.writefile({ mode }, mode_file)
end

-- The client's directory is on PATH except while a case runs with the
-- executable genuinely absent.
local function with_client(on)
    local entry = base .. '/bin:'
    local present = vim.env.PATH:find(entry, 1, true) ~= nil
    if on and not present then
        vim.env.PATH = entry .. vim.env.PATH
    elseif not on and present then
        vim.env.PATH = (vim.env.PATH:gsub(vim.pesc(entry), ''))
    end
end
with_client(true)

--------------------------------------------------------------------------------
-- Fixtures
--------------------------------------------------------------------------------

local gate = require 'config.db_completion'

local reachable = 'sybase://u:p@healthy:5000/reachable_db'
local no_client = 'sybase://u:p@noclient:5000/no_client_db'
local bad_listing = 'sybase://u:p@badlist:5000/bad_listing_db'

local function sql_buffer(url)
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(bufnr, 'scratch:' .. bufnr .. '.sql')
    vim.api.nvim_set_current_buf(bufnr)
    vim.bo[bufnr].filetype = 'sql'
    -- b:db is assigned last, on purpose. The upstream plugin's own FileType
    -- fetch (vim_dadbod_completion/plugin) and this repository's gate autocmds
    -- both fire on FileType/BufEnter, and with no connection visible at that
    -- moment neither attempts anything. Each case therefore reaches its first
    -- determination through the seam it means to exercise (_bind, _open,
    -- refresh, DBExecutePre) rather than through an event it did not ask for.
    if url then
        vim.b[bufnr].db = url
    end
    return bufnr
end

--- Model one keystroke exactly as blink.cmp performs it: ask the gate, and only
--- call the provider if the gate opens. `consulted` is what typing cost the
--- provider; `errors` is what the developer would have seen.
local function simulate_typing(n)
    local consulted, errors = 0, 0
    for _ = 1, n do
        if gate.enabled() then
            consulted = consulted + 1
            local ok = pcall(vim.fn['vim_dadbod_completion#omni'], 0, 'sel')
            if not ok then
                errors = errors + 1
            end
        end
    end
    return consulted, errors
end

--------------------------------------------------------------------------------
-- T011 — gate truth table
--------------------------------------------------------------------------------

-- M.enabled() reads the module's own bindings cache, so a buffer must be bound
-- before the gate can see it. M._bind is the test seam for the bookkeeping half
-- of the autocmd; the truth table is a property of the gate alone, so no
-- determination runs here.
local function gate_for(bufnr)
    gate._bind(bufnr)
    return gate.enabled()
end

vim.print '--- T011: gate truth table ---'

do
    local bufnr = sql_buffer(reachable)
    fail(gate_for(bufnr) == false, 'undetermined connection is closed', gate_for(bufnr), false)

    gate._force(reachable, 'usable')
    fail(gate.enabled() == true, 'usable connection is open', gate.enabled(), true)

    gate._force(reachable, 'warming')
    fail(gate.enabled() == false, 'warming connection is closed', gate.enabled(), false)

    gate._force(reachable, 'unusable')
    fail(gate.enabled() == false, 'unusable connection is closed', gate.enabled(), false)

    -- FR-016: 'undetermined' must never be read as usable.
    gate._force(reachable, 'undetermined')
    fail(gate.enabled() == false, 'undetermined is not readable as usable', gate.enabled(), false)
end

do
    -- FR-003: a SQL buffer with no connection at all.
    local bufnr = sql_buffer(nil)
    fail(gate_for(bufnr) == false, 'unbound SQL buffer is closed', gate_for(bufnr), false)
end

do
    local bufnr = sql_buffer(reachable)
    gate._bind(bufnr)
    gate._force(reachable, 'usable')
    fail(gate.enabled() == true, 'gate open before toggling', gate.enabled(), true)
    gate._set_enabled(false)
    fail(gate.enabled() == false, 'switch off closes the gate', gate.enabled(), false)
    gate._set_enabled(true)
    fail(gate.enabled() == true, 'switch on reopens it', gate.enabled(), true)
end

--------------------------------------------------------------------------------
-- T012 — the differential: typing reaches the provider only when the gate opens
--------------------------------------------------------------------------------

vim.print '--- T012: what typing costs ---'

do
    -- Control. With a working client and a usable connection, the provider IS
    -- consulted on every keystroke -- this is the behavior SC-010 requires to
    -- survive, and it proves the harness genuinely reaches the provider.
    with_client(true)
    stub_set 'ok'
    local bufnr = sql_buffer(reachable)
    gate._open(bufnr)
    fail(gate._state(reachable) == 'usable', 'control: the determination succeeds', gate._state(reachable), 'usable')

    local consulted, control_errors = simulate_typing(20)
    fail(consulted == 20, 'control: gate open means 20 of 20 keystrokes reach the provider', consulted, 20)
    fail(control_errors == 0, 'control: a healthy connection raises nothing', control_errors, 0)
end

do
    -- The reported defect, reproduced: with the client's executable missing,
    -- db#connect() throws before the plugin's retry guard has a record, so the
    -- unguarded provider raises an error on every single keystroke.
    with_client(false)
    stub_set 'ok'
    local bufnr = sql_buffer(no_client)
    gate._bind(bufnr)
    gate._force(no_client, 'usable') -- defeat the gate to measure the old path

    local consulted, errors = simulate_typing(20)
    fail(consulted == 20, 'ungated: the provider is consulted on every keystroke', consulted, 20)
    fail(errors == 20, 'ungated: every keystroke raises the connection error', errors, 20)
end

do
    -- The fix. Same unreachable connection, gate closed: zero provider
    -- consultations and zero errors across a typing burst.
    with_client(false)
    stub_set 'ok'
    local bufnr = sql_buffer(no_client)
    gate._bind(bufnr)
    gate._force(no_client, 'unusable')

    local consulted, errors = simulate_typing(50)
    fail(consulted == 0, 'gated: 50 keystrokes consult the provider zero times', consulted, 0)
    fail(errors == 0, 'gated: 50 keystrokes raise zero errors', errors, 0)
    fail(gate.enabled() == false, 'gate stays closed while typing', gate.enabled(), false)
end

do
    -- The reported defect, at the level dadbod actually reports it: the client
    -- runs and cannot reach the server, so db#connect() throws. One
    -- determination costs exactly one client invocation and ends there, and the
    -- connection is marked unusable instead of being retried forever.
    with_client(true)
    stub_set 'fail'
    local bufnr = sql_buffer(bad_listing)
    local before = client_calls()
    gate._open(bufnr)
    fail(client_calls() == before + 1, 'a determination costs exactly one client call', client_calls() - before, 1)
    fail(
        gate._state(bad_listing) == 'unusable',
        'an unreachable connection is marked unusable',
        gate._state(bad_listing),
        'unusable'
    )

    -- Further typing against the failed connection costs nothing at all.
    local settled = client_calls()
    simulate_typing(50)
    fail(client_calls() == settled, '50 keystrokes after a failure cost zero client calls', client_calls() - settled, 0)
end

do
    -- FR-016: an empty listing is not a verdict. The client answers, the
    -- connection is healthy, and only the table list is empty -- usability must
    -- be established positively, never inferred from the absence of
    -- suggestions, in either direction.
    with_client(true)
    stub_set 'empty'
    local connection = 'sybase://u:p@empt:5000/empty_listing_db'
    local bufnr = sql_buffer(connection)
    gate._open(bufnr)
    fail(
        gate._state(connection) == 'usable',
        'a healthy connection with an empty listing is usable',
        gate._state(connection),
        'usable'
    )
    fail(gate.enabled() == true, 'gate open on the empty listing', gate.enabled(), true)
end

--------------------------------------------------------------------------------
-- T013 — buffer immutability, other sources intact
--------------------------------------------------------------------------------

vim.print '--- T013: buffer untouched, other sources intact ---'

do
    with_client(false)
    stub_set 'ok'
    local bufnr = sql_buffer(no_client)
    local text = { 'select name from sysobjects', 'where type = "U"' }
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, text)
    local modified_before = vim.bo[bufnr].modified
    local db_before = vim.b[bufnr].db

    gate._open(bufnr)
    simulate_typing(50)

    fail(vim.bo[bufnr].filetype == 'sql', 'filetype unchanged', vim.bo[bufnr].filetype, 'sql')
    fail(
        vim.deep_equal(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), text),
        'buffer text unchanged',
        vim.api.nvim_buf_get_lines(bufnr, 0, -1, false),
        text
    )
    fail(vim.b[bufnr].db == db_before, 'b:db unchanged', vim.b[bufnr].db, db_before)
    fail(vim.bo[bufnr].modified == modified_before, 'unsaved state unchanged', vim.bo[bufnr].modified, modified_before)
end

do
    -- FR-005 / FR-010: the non-database sources must survive, and the gate must
    -- be wired. blink.cmp offers no Lua handle for the merged config here, so
    -- assert on the configuration source itself.
    local blink_file = module_root .. '/plugin/blink.lua'
    local source = table.concat(vim.fn.readfile(blink_file), '\n')
    local sources_intact = source:find(
        "sql = { 'vim_dadbod_completion', 'lsp', 'path', 'snippets', 'buffer' }",
        1,
        true
    ) ~= nil
    fail(sources_intact == true, 'other SQL sources still configured', sources_intact, true)
    local gated = source:find('config.db_completion', 1, true) ~= nil
    fail(gated == true, 'gate is wired into the provider options', gated, true)
    local inert_option_kept = source:find("opts = { trigger_characters = { '.', '_' } }", 1, true) ~= nil
    fail(inert_option_kept == true, 'R-0040 deferral left in place, not "fixed"', inert_option_kept, true)
end

--------------------------------------------------------------------------------
-- T024 / T025 — one notice per connection, no cross-talk (US3)
--------------------------------------------------------------------------------

vim.print '--- T024/T025: notice discipline and per-connection scoping ---'

do
    local notices = {}
    local real_notify = require('notifications').notify
    require('notifications').notify = function(message)
        notices[#notices + 1] = message
    end
    with_client(true)

    local function fail_one(connection)
        local bufnr = sql_buffer(connection)
        stub_set 'fail'
        gate._open(bufnr)
    end

    -- Three connections fail independently.
    fail_one 'sybase://u:p@a:5000/db_a'
    fail_one 'sybase://u:p@b:5000/db_b'
    fail_one 'sybase://u:p@c:5000/db_c'
    -- Re-opening buffers on the same connections must neither re-notify nor
    -- re-attempt.
    fail_one 'sybase://u:p@a:5000/db_a'
    fail_one 'sybase://u:p@b:5000/db_b'
    fail_one 'sybase://u:p@c:5000/db_c'

    require('notifications').notify = real_notify

    fail(#notices == 3, 'exactly one notice per failing connection', #notices, 3)

    -- No notice may carry a URL: the argv db#systemlist receives contains
    -- -U/-P, so a client error can quote the password.
    local leaked = false
    for _, message in ipairs(notices) do
        if message:find 'sybase://' or message:find 'u:p@' or message:find '%-P ' then
            leaked = true
        end
    end
    fail(leaked == false, 'no notice contains a connection URL or client argv', leaked, false)

    local named = false
    for _, message in ipairs(notices) do
        if message:find 'db_a' then
            named = true
        end
    end
    fail(named == true, 'notice names the database', named, true)
end

do
    -- An unusable connection must not close the gate for a usable one (FR-005).
    stub_set 'fail'
    local bad = sql_buffer 'sybase://u:p@down2:5000/bad_db'
    gate._open(bad)
    fail(
        gate._state 'sybase://u:p@down2:5000/bad_db' == 'unusable',
        'bad connection unusable',
        gate._state 'sybase://u:p@down2:5000/bad_db',
        'unusable'
    )

    stub_set 'ok'
    local good = sql_buffer 'sybase://u:p@good2:5000/good_db'
    gate._open(good)
    fail(
        gate._state 'sybase://u:p@good2:5000/good_db' == 'usable',
        'good connection usable',
        gate._state 'sybase://u:p@good2:5000/good_db',
        'usable'
    )
    fail(gate.enabled() == true, 'gate open on the good connection', gate.enabled(), true)

    -- And the bad one is still shut when we go back to it.
    vim.api.nvim_set_current_buf(bad)
    gate._bind(bad)
    fail(gate.enabled() == false, 'bad connection still closed', gate.enabled(), false)
end

--------------------------------------------------------------------------------
-- No writes
--------------------------------------------------------------------------------

vim.print '--- module writes no file ---'
do
    local module = debug.getinfo(gate.setup, 'S').source:sub(2)
    local source = table.concat(vim.fn.readfile(module), '\n')
    for _, forbidden in ipairs { 'writefile', 'io.open', 'vim.fn.mkdir', 'vim.uv.fs_' } do
        local used = source:find(forbidden, 1, true) ~= nil
        fail(used == false, 'module does not call ' .. forbidden, used, false)
    end
end

vim.print 'ALL db_completion_smoke ASSERTIONS PASSED'
