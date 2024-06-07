-- Neo-tree is a Neovim plugin to browse the file system
-- https://github.com/nvim-neo-tree/neo-tree.nvim

return {
  "nvim-neo-tree/neo-tree.nvim",
  -- branch = 'v3.x',
  version = "*",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons", -- not strictly required, but recommended
    "MunifTanjim/nui.nvim",
  },
  cmd = "Neotree",
  keys = {
    { ";e", ":Neotree toggle<CR>", { desc = "NeoTree toggle" } },
  },
  opts = {
    filesystem = {
      use_libuv_file_watcher = true,
      follow_current_file = {
        enabled = true,
      },
      window = {
        mappings = {
          ["\\"] = "close_window",
        },
      },
      buffers = {
        follow_current_file = { enabled = true },
      },
    },
  },
}
