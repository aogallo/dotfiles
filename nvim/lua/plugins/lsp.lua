return {
  'neovim/nvim-lspconfig',
  dependencies = {
    { "folke/neodev.nvim", opts = {} },
    {
      'williamboman/mason.nvim',
      config = true
    },
    {
      'williamboman/mason-lspconfig.nvim',
      config = function()
        require("mason-lspconfig").setup({
          ensure_installed = {
            "tsserver",
            "html",
            "csharp_ls",
            "cssls",
            "lua_ls",
            "astro",
            "bashls",
            "dockerls",
            "jsonls",
            "marksman",
            "tailwindcss",
            "yamlls"
          }
        })
      end
    }
  },
  config = function()
    -- require 'allan.plugins.lsp.lspconfig'
    require 'allan.plugins.lsp'
  end
}
