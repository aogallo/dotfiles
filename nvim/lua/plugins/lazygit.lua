return {
  "kdheepak/lazygit.nvim",
  -- optional for floating window border decoration
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  keys = {
    {
      "<leader>gg", ":LazyGit<CR>", desc = "Open Git Tools"
    },
  },
  config = function ()
    vim.g.lazygit_floating_window_scaling_factor=1
    vim.g.lazygit_floating_window_border_chars = {'╭','─', '╮', '│', '╯','─', '╰', '│'}
  end
}
