return {
  'tpope/vim-fugitive',
  keys = {
    {
      "<leader>gg", ":G<CR>", desc = "Open Git Tools"
    },
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
