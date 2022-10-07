-- plugins/init.lua

return require('packer').startup(function()
	use 'wbthomason/packer.nvim' -- Package manager

	--LSP
	use {
		'neovim/nvim-lspconfig',
		'williamboman/nvim-lsp-installer'
	}

	--For highligth syntx
	use { 'nvim-treesitter/nvim-treesitter', run = ':TSUpdate' }
	
	use 'rafcamlet/nvim-luapad'
	use { 'windwp/nvim-ts-autotag' }
	use { 'p00f/nvim-ts-rainbow' }
	use { 'nvim-telescope/telescope.nvim', requires = { { 'nvim-lua/plenary.nvim' } } }
	use { 'folke/which-key.nvim' }
 

	-- vim-devicons
	--
	use { 'ryanoasis/vim-devicons' }


	--NVIM-TREE
	use {
    'kyazdani42/nvim-tree.lua',
    requires = {
      'kyazdani42/nvim-web-devicons', -- optional, for file icons
    },
    tag = 'nightly' -- optional, updated every week. (see issue #1193)
  }
	 
	-- using packer.nvim
	use {'akinsho/bufferline.nvim', tag = "v2.*", requires = 'kyazdani42/nvim-web-devicons'}

	--theme
	use { "ellisonleao/gruvbox.nvim" }
	--use { 'sainnhe/gruvbox-material' }
	

	-- Comments
  use {
      'numToStr/Comment.nvim',
      config = function()
          require('Comment').setup()
      end
  }
	-- Lualine
	use {
		'nvim-lualine/lualine.nvim',
		requires = { 'kyazdani42/nvim-web-devicons', opt = true }
	}

	-- Git
	use 'mhinz/vim-signify'
	use 'tpope/vim-fugitive'
	use 'tpope/vim-rhubarb'
	use 'junegunn/gv.vim'
	-- Compleition
	use 'hrsh7th/cmp-nvim-lsp'
	use 'hrsh7th/cmp-buffer'
	use 'hrsh7th/cmp-path'
	use 'hrsh7th/cmp-cmdline'
	use 'hrsh7th/nvim-cmp'

	use 'windwp/nvim-autopairs'

	--This tiny plugin adds vscode-like pictograms to neovim built-in lsp:
	use 'onsails/lspkind-nvim'
  use { 'hrsh7th/cmp-vsnip' }
  use { 'hrsh7th/vim-vsnip' }

	--Ale for standard javascript
	use 'dense-analysis/ale'

  --To work with any database
  use {
    'kristijanhusak/vim-dadbod-ui',
    requires = {
        'tpope/vim-dadbod',
        'tpope/vim-dotenv'
    }
  }
	--Automaticly set up your configuration after clonning pachker.nvim 
	--Put this at the end after the all plugins
	if PACKER_BOOTSTRAP then
		require('packer').sync()
	end

end)

