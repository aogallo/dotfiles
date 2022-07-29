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
	use { 'stsewd/tree-sitter-comment' }

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
	-- For vsnip users
	use 'hrsh7th/cmp-vsnip'
	use 'hrsh7th/vim-vsnip'

	-- For luasnip users
	use 'L3MON4D3/LuaSnip'
	use 'saadparwaiz1/cmp_luasnip'

	--For ultisnips users	
	use 'hrsh7th/cmp-nvim-lua'
	use 'onsails/lspkind-nvim'
	use 'hrsh7th/cmp-nvim-lsp-signature-help'
	use 'windwp/nvim-autopairs'

	use 'rafamadriz/friendly-snippets'


	-- Hydra 
	use 'anuvyklack/hydra.nvim' 

	--LSP Saga
	use({
    "glepnir/lspsaga.nvim",
    branch = "main",
	})
	--Automaticly set up your configuration after clonning pachker.nvim 
	--Put this at the end after the all plugins
	if PACKER_BOOTSTRAP then
		require('packer').sync()
	end

end)

