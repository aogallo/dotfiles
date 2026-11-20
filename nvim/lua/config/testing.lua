local M = {}

function M.setup()
    require('neotest').setup {
        adapters = {
            require 'neotest-golang' {
                runner = 'gotestsum',
                go_test_args = { '-v', '-count=1' },
            },
        },
        status = { enabled = true, signs = true },
        summary = { enabled = true },
        output = { enabled = true },
        output_panel = { enabled = true },
        diagnostic = { enabled = true },
    }
end

function M.run_module()
    local root = vim.fs.root(0, { 'go.mod' })
    if not root then
        vim.notify('No go.mod found for the current buffer', vim.log.levels.WARN)
        return
    end
    require('neotest').run.run(root)
end

return M
