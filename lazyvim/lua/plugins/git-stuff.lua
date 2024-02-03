return {
  {
    "pwntester/octo.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
      require("octo").setup({ enable_builtin = true })
      vim.cmd([[hi OctoEditable guibg=noe]])
    end,
    keys = {
      {
        "<leader>O",
        "<cmd>Octo<cr>",
        desc = "Octo",
      },
      {
        "<leader>Opd",
        "<cmd>Octo pr draft<cr>",
        desc = "Send PR to Draft",
      },
      {
        "<leader>Oprs",
        "<cmd>Octo review start<cr>",
        desc = "Start reviewing PR",
      },
    },
  },
}
