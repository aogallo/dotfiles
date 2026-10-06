-- Smoke test: db_completion_gate_healthy_smoke (specs/archive/2026-10-06-001-db-completion-gate)
-- User Story 5: with a healthy connection, the gated provider offers exactly
-- what the ungated provider offers. The gate is consulted before suggestions
-- are requested; it must never mutate the provider's own cache or notice.
--
-- Requires: vim-dadbod, vim-dadbod-completion, blink.cmp, which-key, and a
-- fake sqsh on PATH. Offline only — no real database or client binary.
--
-- Run (from this directory):
--   nvim --headless -u NORC -c 'lua require("tests.db_completion_gate_healthy_smoke")' -c 'qa!'
--
-- SQL: none
-- Stub DB: sqsh writes a line to $DB_SMOKE_COUNT and prints a table list

local module_root = vim.fn.fnamemodify(vim.fn.expand '<sfile>:p:h:h:h', ':p')
vim.opt.runtimepath:prepend(module_root)

-- The fake sqsh client: counts every invocation, always healthy.
local client_dir = vim.fn.tempname()
vim.fn.mkdir(client_dir .. '/bin', 'p')
vim.fn.writefile({
    '#!/bin/sh',
    'printf "x\\n" >> "$DB_SMOKE_COUNT"',
    'echo mytable',
    'exit 0',
}, client_dir .. '/bin/sqsh')
os.execute('chmod +x ' .. client_dir .. '/bin/sqsh')
vim.env.DB_SMOKE_COUNT = client_dir .. '/count'
vim.fn.writefile({}, vim.env.DB_SMOKE_COUNT)
vim.env.PATH = client_dir .. '/bin:' .. vim.env.PATH

local gate = require 'config.db_completion'

local passed, failed = 0, 0
local function check(ok, name, got, want)
    if ok then
        passed = passed + 1
        print('PASS ' .. name)
    else
        failed = failed + 1
        print('FAIL ' .. name)
        if got ~= nil then
            print('  got:  ' .. vim.inspect(got))
        end
        if want ~= nil then
            print('  want: ' .. vim.inspect(want))
        end
    end
end

-- T036 sink: zero notices about database completion across the session.
local original_notify = vim.notify
local completion_notices = {}
vim.notify = function(msg, level, _opts)
    local text = tostring(msg)
    if
        text:find('Schema completion', 1, true) ~= nil
        or text:find('Database completion', 1, true) ~= nil
        or text:find('DBCompletionRefresh', 1, true) ~= nil
        or text:find('bound to this buffer', 1, true) ~= nil
    then
        table.insert(completion_notices, text)
        return
    end
    original_notify(msg, level, _opts)
end

-- Fixture: one SQL buffer on a healthy connection, opened once so the
-- determination runs before any assertion reads suggestions.
local url = 'sybase://u:p@h:5000/healthy_db'
local buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_name(buf, 'healthy.sql')
vim.api.nvim_set_current_buf(buf)
vim.bo[buf].filetype = 'sql'
vim.b[buf].db = url
gate._open(buf)

-- Gate is open on a healthy connection: blink would consult the provider.
check(gate.enabled() == true, 'a healthy connection opens the gate', gate.enabled(), true)

-- The four prefix classes, each captured with the gate consulted first and
-- then again raw — the ungated baseline is the provider itself.
local function suggestions_for(base_str, line, cursor_col)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { line })
    vim.api.nvim_win_set_cursor(0, { 1, cursor_col })
    local words = {}
    local ok, items = pcall(vim.fn['vim_dadbod_completion#omni'], 0, base_str)
    if ok and type(items) == 'table' then
        for _, item in ipairs(items) do
            words[#words + 1] = type(item) == 'table' and item.word or tostring(item)
        end
    end
    local start_ok, start = pcall(vim.fn['vim_dadbod_completion#omni'], 1, base_str)
    return {
        words = words,
        findstart = start_ok and start or nil,
        findstart_ok = start_ok,
    }
end

local classes = {
    { name = 'table prefix', base = 'myt', line = 'select myt', col = 10, expect = 'mytable' },
    { name = 'bare prefix', base = 'zzz', line = 'select zzz', col = 10, expect = nil },
    { name = 'dot-triggered', base = 'mytable.', line = 'select mytable.', col = 16, expect = nil },
    { name = 'reserved word prefix', base = 'sel', line = 'select sel', col = 10, expect = 'SELECT' },
}

for _, class in ipairs(classes) do
    local gated = suggestions_for(class.base, class.line, class.col)
    -- Consult the gate the way blink does, then capture the raw provider.
    local enabled = gate.enabled()
    local ungated = suggestions_for(class.base, class.line, class.col)
    check(enabled, class.name .. ': gate stays open', enabled, true)
    check(
        vim.deep_equal(gated.words, ungated.words) and gated.findstart == ungated.findstart,
        class.name .. ': gated and ungated suggestion sets are identical',
        { gated = gated, ungated = ungated },
        'identical'
    )
    if class.expect then
        local found = false
        for _, word in ipairs(ungated.words) do
            if word == class.expect then
                found = true
                break
            end
        end
        check(found, class.name .. ': suggestion still present', ungated.words, class.expect)
    end
end

-- Repeated gate consultation must not shift the provider's answers (no
-- cache mutation, no state bleed from M.enabled()).
local first = suggestions_for('myt', 'select myt', 10)
for _ = 1, 50 do
    gate.enabled()
end
local after = suggestions_for('myt', 'select myt', 10)
check(
    vim.deep_equal(first.words, after.words),
    '50 gate consultations leave the suggestion set unchanged',
    after.words,
    first.words
)

-- T036: a healthy session emits zero database-completion notices.
check(#completion_notices == 0, 'zero completion notices in a healthy session', completion_notices, {})

vim.notify = original_notify
print(string.format('DB COMPLETION GATE HEALTHY SMOKE: %d passed, %d failed', passed, failed))
if failed > 0 then
    vim.cmd 'cquit'
end
