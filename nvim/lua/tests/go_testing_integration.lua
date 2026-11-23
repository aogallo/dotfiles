-- Isolated real-plugin test. See README for runtime layout and environment.
local function report(message)
    print(message)
    if vim.env.NEOTEST_RUNTIME then
        vim.fn.writefile(
            vim.split(message, '\n', { plain = true }),
            vim.env.NEOTEST_RUNTIME .. '/integration-assertions.log',
            'a'
        )
    end
end

local function check()
    local repo = vim.fn.getcwd()
    local runtime = assert(vim.env.NEOTEST_RUNTIME, 'set NEOTEST_RUNTIME to an isolated plugin/runtime directory')
    local absolute = runtime:sub(1, 1) == '/' or runtime:match '^%a:[/\\]' or runtime:match '^\\\\[^\\]+\\[^\\]+'
    assert(absolute, 'NEOTEST_RUNTIME must be absolute')
    vim.opt.rtp:prepend(repo .. '/nvim')
    for _, name in ipairs { 'plenary.nvim', 'nvim-nio', 'neotest-golang', 'neotest', 'nvim-treesitter' } do
        vim.opt.rtp:append(runtime .. '/' .. name)
    end
    vim.opt.rtp:prepend(runtime)
    assert(#vim.api.nvim_list_uis() > 0, 'run in a normal Neovim UI, not with --headless or -l')
    vim.g.mapleader = ' '
    local fixture = assert(vim.uv.fs_mkdtemp(runtime .. '/fixture-XXXXXX'))
    vim.fn.writefile({ 'module example.com/neotest-fixture', '', 'go 1.20' }, fixture .. '/go.mod')
    vim.fn.writefile({
        'package fixture',
        'import ("testing"; "time")',
        'func TestPass(t *testing.T) { time.Sleep(500*time.Millisecond); t.Log("PASS OUTPUT MARKER") }',
        'func TestFail(t *testing.T) { t.Error("FAIL OUTPUT MARKER") }',
        'func TestSkip(t *testing.T) { t.Skip("SKIP OUTPUT MARKER") }',
    }, fixture .. '/sample_test.go')
    vim.fn.writefile(
        { 'package fixture', 'import "testing"', 'func TestSibling(t *testing.T) {}' },
        fixture .. '/other_test.go'
    )
    vim.fn.mkdir(fixture .. '/child', 'p')
    vim.fn.writefile(
        { 'package child', 'import "testing"', 'func TestChild(t *testing.T) {}' },
        fixture .. '/child/child_test.go'
    )
    vim.cmd.cd(fixture)
    vim.cmd.edit(fixture .. '/sample_test.go')
    vim.bo.filetype = 'go'
    local test_buffer, test_window = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
    -- Exercise the real declaration/configuration, without vim.pack installing anything.
    package.loaded['vim-pack'] = { add = function() end }
    package.loaded['which-key'] = { add = function() end }
    dofile(repo .. '/nvim/plugin/testing.lua')
    -- Match the actual startup ordering: testing.lua precedes Treesitter setup.
    require('nvim-treesitter').setup {}
    vim.opt.rtp:prepend(runtime .. '/nvim-treesitter/runtime')
    local neotest = require 'neotest'
    local completed = 0
    local setup = neotest.setup
    neotest.setup = function(options)
        -- Public consumer extension: streamed signs may precede process completion.
        options.consumers = {
            integration_completion = function(client)
                client.listeners.results = function(_, _, partial)
                    if not partial then
                        completed = completed + 1
                    end
                end
            end,
        }
        setup(options)
    end
    vim.api.nvim_exec_autocmds('VimEnter', {})
    local function wait(label, predicate)
        assert(vim.wait(90000, predicate, 20), 'timeout: ' .. label)
    end
    local function press(key)
        vim.fn.maparg(' ' .. key, 'n', false, true).callback()
    end
    local function signs()
        local result = {}
        for _, sign in ipairs(vim.fn.sign_getplaced(test_buffer, { group = 'neotest-status' })[1].signs) do
            result[sign.lnum] = sign.name
        end
        return result
    end
    -- The client starts lazily: opening the summary requests discovery without running tests.
    neotest.summary.open()
    wait('discovery', function()
        return signs()[3] == 'neotest_test'
    end)
    local adapter = assert(neotest.state.adapter_ids()[1])
    wait('discovered counts', function()
        local counts = neotest.state.status_counts(adapter)
        return counts and counts.total == 5 and counts.passed == 0 and counts.failed == 0
    end)
    report 'PASS discovery: five tests, none falsely passed'
    neotest.summary.close()
    vim.api.nvim_set_current_win(test_window)
    vim.api.nvim_win_set_cursor(test_window, { 3, 0 })
    press 'tn'
    wait('running sign', function()
        return signs()[3] == 'neotest_running'
    end)
    wait('nearest pass', function()
        return signs()[3] == 'neotest_passed'
    end)
    assert(signs()[4] == 'neotest_test' and signs()[5] == 'neotest_test', 'nearest excludes other tests')
    wait('nearest process complete', function()
        return completed == 1
    end)
    press 'tl'
    wait('rerun running', function()
        return signs()[3] == 'neotest_running'
    end)
    wait('rerun passed', function()
        return signs()[3] == 'neotest_passed'
    end)
    wait('repeat process complete', function()
        return completed == 2
    end)
    report 'PASS nearest and repeat: running then passed, other tests unexecuted'
    press 'tf'
    wait('file results', function()
        return signs()[4] == 'neotest_failed' and signs()[5] == 'neotest_skipped'
    end)
    wait('file counts', function()
        local c = neotest.state.status_counts(adapter)
        return c.passed == 1 and c.failed == 1 and c.skipped == 1 and c.running == 0
    end)
    wait('file process complete', function()
        return completed == 3
    end)
    report 'PASS file: passed/failed/skipped signs and counts; sibling/child excluded'
    vim.api.nvim_win_set_cursor(test_window, { 4, 0 })
    press 'to'
    local function buffer_text(filetype)
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            if vim.bo[buf].filetype == filetype then
                return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n')
            end
        end
        return ''
    end
    wait('per-test output', function()
        return buffer_text('neotest-output'):find('FAIL OUTPUT MARKER', 1, true) ~= nil
    end)
    assert(not buffer_text('neotest-output'):find('PASS OUTPUT MARKER', 1, true), 'output specific to failed test')
    report 'PASS nearest output: failure message, no passing-test output'
    vim.api.nvim_set_current_win(test_window)
    press 'tt'
    wait('summary', function()
        local text = buffer_text 'neotest-summary'
        return text:find('TestPass', 1, true) and text:find('TestFail', 1, true) and text:find('TestSkip', 1, true)
    end)
    report 'PASS summary: individual passing/failing/skipped tests visible'
    neotest.summary.close()
    vim.api.nvim_set_current_win(test_window)
    -- Run from a child package: suite must select the whole buffer module, not just cwd.
    vim.cmd.cd(fixture .. '/child')
    report(
        'SUITE context: buffer=' .. vim.api.nvim_buf_get_name(0) .. ' module=' .. tostring(vim.fs.root(0, { 'go.mod' }))
    )
    press 'ts'
    wait('suite counts', function()
        local c = neotest.state.status_counts(adapter)
        return c.passed == 3 and c.failed == 1 and c.skipped == 1 and c.running == 0
    end)
    wait('suite process complete', function()
        return completed == 4
    end)
    press 'tO'
    wait('output panel', function()
        for _, win in ipairs(vim.api.nvim_list_wins()) do
            if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == 'neotest-output-panel' then
                return true
            end
        end
        return false
    end)
    report 'PASS module suite from child cwd: sibling and child included; output panel opens'
    vim.fn.writefile({ 'PASS complete Neotest UI integration' }, runtime .. '/integration-success')
    report('Fixture retained for inspection: ' .. fixture)
end
local ok, err = xpcall(check, debug.traceback)
if not ok then
    report(tostring(err))
    vim.api.nvim_err_writeln(tostring(err))
    vim.cmd 'cquit 1'
end
vim.cmd 'qa!'
