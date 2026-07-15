-- Enable the experimental Lua module loader
vim.loader.enable()

-- Global variables
-- vim.g.projects_dir = vim.env.HOME
--

require 'config.options'
require 'config.keymaps'
require 'config.autocmds'
require 'statusline'
require 'lsp'

vim.lsp.config('*', {
    capabilities = {
        textDocument = {
            semanticTokens = {
                multilineTokenSupport = true,
            },
        },
    },
    root_markers = { '.git' },
})

require('vim._core.ui2').enable {}
