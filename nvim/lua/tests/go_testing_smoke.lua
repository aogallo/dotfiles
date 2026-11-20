-- Offline configuration contract; no plugin downloads or personal init.
local function check()
    vim.opt.rtp:prepend(vim.fn.getcwd() .. '/nvim')
    vim.g.mapleader = ' '
    local specs, groups, options, adapter_options
    local calls = {}
    package.loaded['vim-pack'] = {
        add = function(value)
            specs = value
        end,
    }
    package.loaded['which-key'] = {
        add = function(value)
            groups = value
        end,
    }
    local function record(name)
        return function(arg)
            calls[#calls + 1] = { name, arg }
        end
    end
    package.loaded.neotest = {
        setup = function(value)
            options = value
        end,
        run = { run = record 'run', run_last = record 'last', stop = record 'stop' },
        summary = { toggle = record 'summary' },
        output = { open = record 'output' },
        output_panel = { toggle = record 'panel' },
    }
    package.loaded['neotest-golang'] = function(value)
        adapter_options = value
        return 'go-adapter'
    end
    dofile 'nvim/plugin/testing.lua'
    assert(specs[1].src == 'nvim-neotest/nvim-nio' and specs[1].setup == false, 'nio dependency')
    assert(specs[2].src == 'fredrikaverpil/neotest-golang' and specs[2].setup == false, 'Go adapter')
    assert(specs[3].src == 'nvim-neotest/neotest' and specs[3].setup == false, 'deferred Neotest')
    assert(not options, 'setup waits for Treesitter plugin loading')
    vim.api.nvim_exec_autocmds('VimEnter', {})
    assert(options.adapters[1] == 'go-adapter', 'adapter wired')
    assert(adapter_options.runner == 'gotestsum', 'file-backed JSON runner avoids truncated stdout')
    assert(
        vim.deep_equal(adapter_options.go_test_args, { '-v', '-count=1' }),
        'Go arguments preserve uncached runs without race/coverage extras'
    )
    for _, consumer in ipairs { 'status', 'summary', 'output', 'output_panel', 'diagnostic' } do
        assert(options[consumer].enabled, consumer .. ' enabled')
    end
    assert(options.status.signs, 'status signs enabled')
    assert(groups[1][1] == '<leader>t' and groups[1].group == 'tests', 'which-key group')
    local function press(key)
        local mapping = vim.fn.maparg(' ' .. key, 'n', false, true)
        assert(type(mapping.callback) == 'function' and mapping.desc, 'mapping ' .. key)
        mapping.callback()
        return calls[#calls]
    end
    assert(press('tn')[1] == 'run' and calls[#calls][2] == nil, 'nearest preserved')
    vim.api.nvim_buf_set_name(0, '/fixture/module/child/sample_test.go')
    assert(press('tf')[2] == '/fixture/module/child/sample_test.go', 'file run uses buffer')
    local root = vim.fs.root
    vim.fs.root = function(source, markers)
        assert(source == 0 and markers[1] == 'go.mod', 'suite uses current buffer module')
        return '/fixture/module'
    end
    assert(press('ts')[2] == '/fixture/module', 'suite ignores unrelated cwd')
    local count = #calls
    local notify = vim.notify
    local notice
    vim.notify = function(message, level)
        notice = { message, level }
    end
    vim.fs.root = function()
        return nil
    end
    press 'ts'
    assert(#calls == count and notice[1] == 'No go.mod found for the current buffer', 'missing module never runs cwd')
    assert(notice[2] == vim.log.levels.WARN, 'missing module warning')
    vim.fs.root, vim.notify = root, notify
    assert(press('tl')[1] == 'last', 'repeat preserved')
    assert(press('tt')[1] == 'summary', 'summary')
    assert(press('to')[1] == 'output' and calls[#calls][2].enter, 'nearest output')
    assert(press('tO')[1] == 'panel', 'output panel')
    assert(press('tx')[1] == 'stop' and calls[#calls][2].interactive, 'select running test to stop')
    assert(vim.fn.maparg(' tv', 'n') == '', 'no fake TestVisit')
    print 'PASS Neotest dependencies, deferred setup, Go runner, consumers, execution and output mappings, module guard'
end
local ok, err = pcall(check)
if not ok then
    vim.api.nvim_err_writeln(tostring(err))
    vim.cmd 'cquit 1'
end
vim.cmd 'qa!'
