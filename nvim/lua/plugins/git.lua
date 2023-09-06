return {
  {
      'tpope/vim-fugitive',
  config = function()
    require 'allan.plugins.fugitive'
  end

  },
  {
    'lewis6991/gitsigns.nvim',
    config=true
  },
  {
  "f-person/git-blame.nvim",
  event = "BufRead",
  config = function()
    vim.cmd "highlight default link gitblame SpecialComment"
    require("gitblame").setup { enabled = false }
  end,
},
}
