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
        "<leader>gpd",
        "<cmd>Octo pr draft<cr>",
        desc = "Send PR to Draft",
      },
      {
        "<leader>gprs",
        "<cmd>Octo review start<cr>",
        desc = "Start reviewing PR",
      },
      {
        "<leader>gpl",
        "<cmd>Octo pr list<cr>",
        desc = "PR list",
      },
      {
        "<leader>gpb",
        "<cmd>Octo pr browser<cr>",
        desc = "Open PR on the browser",
      },
      {
        "<leader>gpc",
        "<cmd>Octo pr create<cr>",
        desc = "Create a PR ",
      },
      {
        "<leader>gvb",
        function()
          require("octo.commands").add_user("reviewer")
        end,
        desc = "Add the bezlio team as reviewer",
      },
    },
  },
}
