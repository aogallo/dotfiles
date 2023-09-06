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
    dependencies = {
      'nvim-treesitter/nvim-treesitter-textobjects',
      'HiPhish/nvim-ts-rainbow2',
      'theHamsta/nvim-treesitter-pairs',
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
        config=true
      },
      {
        'williamboman/mason-lspconfig.nvim',
        config = function()
          require ( "mason-lspconfig").setup({
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
}
