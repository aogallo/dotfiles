local ensure_packer = function()
  local fn = vim.fn
  local install_path = fn.stdpath('data')..'/site/pack/packer/start/packer.nvim'
  if fn.empty(fn.glob(install_path)) > 0 then
    fn.system({'git', 'clone', '--depth', '1', 'https://github.com/wbthomason/packer.nvim', install_path})
    vim.cmd [[packadd packer.nvim]]
    return true
  end
  return false
end

local packer_bootstrap = ensure_packer()

vim.cmd([[
  augroup packer_user_config
    autocmd!
    autocmd BufWritePost plugins-setup.lua source <afile> | PackerCompile
  augroup end
]])


local status, packer = pcall(require, "packer")
if not status then return end

return packer.startup(function(use)
  use 'wbthomason/packer.nvim'

  use 'nvim-lua/plenary.nvim'

  use 'kyazdani42/nvim-web-devicons'

  use 'bluz71/vim-nightfly-guicolors' -- theme

  use 'ellisonleao/gruvbox.nvim' -- theme groupbox

  -- use ('christoomey/vim-tmux-navigator') -- tmux & split navigation

  use ('szw/vim-maximizer') -- maximizes and resotres current window

  use 'numToStr/Comment.nvim' -- comments

  use 'kyazdani42/nvim-tree.lua' -- tree

  use 'nvim-lualine/lualine.nvim' -- statusline

  -- Telescope
  use ({ "nvim-telescope/telescope-fzf-native.nvim", run = "make" })
  use ({ "nvim-telescope/telescope.nvim", branch = "0.1.x" })

  -- autocompletion
  use 'hrsh7th/nvim-cmp'
  use 'hrsh7th/cmp-buffer'
  use 'hrsh7th/cmp-path'

  -- snippets
  use({"L3MON4D3/LuaSnip", tag = "v<CurrentMajor>.*"})
  use 'saadparwaiz1/cmp_luasnip'
  use 'rafamadriz/friendly-snippets'

  -- LSP
  use 'williamboman/mason.nvim'
  use 'williamboman/mason-lspconfig.nvim'
  use 'neovim/nvim-lspconfig'
  use 'hrsh7th/cmp-nvim-lsp'
  use ({ "glepnir/lspsaga.nvim", branch = "main" })
  use 'jose-elias-alvarez/typescript.nvim'
  use 'onsails/lspkind.nvim'

  -- Highlighting Syntax
  use {
    'nvim-treesitter/nvim-treesitter',
    run = function() require('nvim-treesitter.install').update({ with_sync = true }) end
  }

  -- Autopairs
  use 'windwp/nvim-autopairs'
  use 'windwp/nvim-ts-autotag'
  -- Rainbow
  use 'p00f/nvim-ts-rainbow'

  -- Git
  use 'lewis6991/gitsigns.nvim'
  use 'tpope/vim-fugitive'
  use 'tpope/vim-rhubarb'
  use 'junegunn/gv.vim'

  -- Automatically set up your configuration after cloning packer.nvim
  -- Put this at the end after all plugins
  if packer_bootstrap then
    require('packer').sync()
  end
end)
