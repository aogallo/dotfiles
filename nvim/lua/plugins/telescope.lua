return {
  'nvim-telescope/telescope.nvim',
  tag = '0.1.2',
  dependencies = { 'nvim-lua/plenary.nvim',
'BurntSushi/ripgrep',
},
  config = function()
    require "allan.plugins.telescope"
  end
}

