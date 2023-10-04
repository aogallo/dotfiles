return {
  'tpope/vim-fugitive',
  keys = {
    {
      "<leader>gp", ":G pull<CR>", desc = "Git PUll"

    },
    {
      "<leader>gs", ":G status<CR>", desc = "Git Sttatus"

    },
    {
      "<leader>gu", ":G push<CR>", desc = "Git push"

    },
    {
      "<leader>gx", ":q<CR>", desc = "Close git tools"
    }
  }
}
