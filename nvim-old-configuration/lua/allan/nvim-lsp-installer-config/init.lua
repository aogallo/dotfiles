require("nvim-lsp-installer").setup({
    automatic_installation = true, -- automatically detect which servers to install (based on which servers are set up via lspconfig)
    ui = {
        icons = {
            server_installed = "✓",
            server_pending = "➜",
            server_uninstalled = "✗"
        }
    }
})


local lspconfig = require('lspconfig')

lspconfig.sumneko_lua.setup{}
lspconfig.pyright.setup{}
lspconfig.sqlls.setup{}
lspconfig.vimls.setup{}
lspconfig.graphql.setup{}
lspconfig.tsserver.setup{}
lspconfig.yamlls.setup{}
lspconfig.eslint.setup{}
