return {
  {
    'tpope/vim-commentary',
    config = function()
      require "allan.plugins.comment"
    end
  },
  {
    'navarasu/onedark.nvim',
    config = function(plugin)
      --print(vim.inspect(plugin))
      vim.cmd("colorscheme onedark")
    end
  },
  {
    'tpope/vim-fugitive',
    config = function()
      require 'allan.plugins.fugitive'
    end

  },
  {
    "f-person/git-blame.nvim",
    event = "BufRead",
    config = function()
      vim.cmd "highlight default link gitblame SpecialComment"
      require("gitblame").setup { enabled = false }
    end,
  },
  {
    'lewis6991/gitsigns.nvim',
    opts = {
      numhl = true
    }
  },
  {
    'nvim-treesitter/nvim-treesitter',
    -- enabled = false,
    build = ":TSUpdate",
    dependencies = {
      'nvim-treesitter/nvim-treesitter-textobjects',
      'HiPhish/nvim-ts-rainbow2',
      'windwp/nvim-autopairs',
      'windwp/nvim-ts-autotag'
    },
    config = function()
      require "allan.plugins.nvim-treesitter"
      require "allan.plugins.autopairs"
    end
  },
  {
    'nvim-telescope/telescope.nvim',
    tag = '0.1.2',
    dependencies = { 'nvim-lua/plenary.nvim',
      'BurntSushi/ripgrep',
    },
    config = function()
      require "allan.plugins.telescope"
    end
  },
  {
    'nvim-tree/nvim-tree.lua',
    dependencies = {
      'nvim-tree/nvim-web-devicons'
    },
    config = function()
      require "allan.plugins.nvim-tree"
    end
  },
  {
    'neovim/nvim-lspconfig',
    dependencies = {
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
  },
  {
    'hrsh7th/nvim-cmp',
    dependencies = {
      { 'hrsh7th/cmp-nvim-lsp' },
      { 'hrsh7th/cmp-buffer' },
      { 'hrsh7th/cmp-path' },
      { 'hrsh7th/cmp-cmdline' },
      { 'L3MON4D3/LuaSnip' }
    },
    config = function()
      require 'allan.plugins.nvimcmp'
    end
  },
  {
    'nvim-lualine/lualine.nvim',
    config = function()
      require 'allan.plugins.lualine'
    end
  },
  {
    'jose-elias-alvarez/null-ls.nvim',
    config = function()
      -- require 'allan.plugins.null-ls'
      local augroup = vim.api.nvim_create_augroup("LspFormatting", {})
      require("null-ls").setup({
        -- you can reuse a shared lspconfig on_attach callback here
        on_attach = function(client, bufnr)
          print(vim.inspect(client))
          if client.supports_method("textDocument/formatting") then
            vim.api.nvim_clear_autocmds({ group = augroup, buffer = bufnr })
            vim.api.nvim_create_autocmd("BufWritePre", {
              group = augroup,
              buffer = bufnr,
              callback = function()
                -- on 0.8, you should use vim.lsp.buf.format({ bufnr = bufnr }) instead
                -- on later neovim version, you should use vim.lsp.buf.format({ async = false }) instead
                -- vim.lsp.buf.formatting_sync()
                vim.lsp.buf.format({async=true})
              end,
            })
          end
        end,
      })
    end
  },
    {
    -- Add indentation guides even on blank lines
    'lukas-reineke/indent-blankline.nvim',
    -- Enable `lukas-reineke/indent-blankline.nvim`
    -- See `:help indent_blankline.txt`
    opts = {
      char = '┊',
      show_trailing_blankline_indent = false,
    },
  },
}
