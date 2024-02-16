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
        "<leader>o",
        "<cmd>Octo<cr>",
        desc = "Octo",
      },
      {
        "<leader>opd",
        "<cmd>Octo pr draft<cr>",
        desc = "Send PR to Draft",
      },
      {
        "<leader>oprs",
        "<cmd>Octo review start<cr>",
        desc = "Start reviewing PR",
      },
      {
        "<leader>opl",
        "<cmd>Octo pr list<cr>",
        desc = "PR list",
      },
      {
        "<leader>opb",
        "<cmd>Octo pr browser<cr>",
        desc = "Open PR on the browser",
      },
      {
        "<leader>opc",
        "<cmd>Octo pr create<cr>",
        desc = "Create a PR ",
      },
    },
  },
}
