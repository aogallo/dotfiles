-- Plenary is already loaded by editor.lua; Treesitter loads after this file.
require('vim-pack').add {
    { src = 'nvim-neotest/nvim-nio', setup = false },
    { src = 'fredrikaverpil/neotest-golang', setup = false },
    { src = 'nvim-neotest/neotest', setup = false },
}

-- Let treesitter.lua finish adding parser/query runtime paths before discovery.
vim.api.nvim_create_autocmd('VimEnter', {
    once = true,
    callback = function()
        require('config.testing').setup()
    end,
})

require('which-key').add {
    { '<leader>t', group = 'tests' },
}

local function neotest()
    return require 'neotest'
end

local mappings = {
    tn = {
        function()
            neotest().run.run()
        end,
        'Run nearest test',
    },
    tf = {
        function()
            neotest().run.run(vim.fn.expand '%:p')
        end,
        'Run test file',
    },
    ts = {
        function()
            require('config.testing').run_module()
        end,
        'Run Go module tests',
    },
    tl = {
        function()
            neotest().run.run_last()
        end,
        'Repeat last test run',
    },
    tt = {
        function()
            neotest().summary.toggle()
        end,
        'Toggle test summary',
    },
    to = {
        function()
            neotest().output.open { enter = true }
        end,
        'Nearest test output',
    },
    tO = {
        function()
            neotest().output_panel.toggle()
        end,
        'Toggle test output panel',
    },
    tx = {
        function()
            neotest().run.stop { interactive = true }
        end,
        'Stop a running test',
    },
}
for key, mapping in pairs(mappings) do
    vim.keymap.set('n', '<leader>' .. key, mapping[1], { desc = mapping[2], silent = true })
end
