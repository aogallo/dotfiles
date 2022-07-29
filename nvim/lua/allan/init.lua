-- init.lua
--

require('allan.settings')		-- lua/settings.lua
require('allan.maps')			-- lua/maps.lua
-- require('allan.statusline')		-- lua/statusline.lua
require('allan.plugins')		-- lua/plugins/init.lua 
require('allan.nvim-web-devicons-config')  -- lua/nvim-web-devicons
require('allan.nvim-tree-config') -- lua/nvim-tree-config'
require('allan.telescope-config')
require('allan.whichkey-config')
require('allan.treesitter-config')
require('allan.bufferline-config')

require('allan.lualine-config')


--icons
--require('allan.icons')

--Git
require('allan.vim-fugitive-config')
require('allan.signify-config')


--LSP 
require('allan.nvim-lsp-installer-config')
require('allan.completation-config')


--HYDRA
--require('allan.hydra-config')

--lSP SAGA
require('allan.lspsaga-config')
