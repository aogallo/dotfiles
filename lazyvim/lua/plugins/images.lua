return {
  "folke/snacks.nvim",
  ---@type snacks.config
  opts = {
    image = {
      enabled = true,
      inline = vim.g.neovim_mode == "skitty" and true or false,
      float = true,
      max_width = vim.g.neovim_mode == "skitty" and 20 or 60,
      max_height = vim.g.neovim_mode == "skitty" and 10 or 30,
    },
  },
}
