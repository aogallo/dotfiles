return {
  {
    "pwntester/octo.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    opts = {
      enable_builtin = true,
      default_to_projects_v2 = true,
      default_merge_method = "squash",
      picker = "telescope",
    },
    keys = {
      -- create a pull request
      { "<leader>go", "<cmd>Octo pr create<CR>", desc = "Create Pull Request (Octo)" },
      -- set draft pr
      { "<leader>gD", "<cmd>Octo pr draft<cr>", desc = "Send PR to Draft (Octo)" },
      -- open pull request in browser
      { "<leader>ga", "<cmd>Octo pr browser<cr>", desc = "Open PR in browser (Octo)" },
      -- copy pr url to clipboard
      { "<leader>gu", "<cmd>Octo pr url<cr>", desc = "Copy PR URL (Octo)" },
      --  add bezlio reviwers
      {
        "<leader>vb",
        function()
          local octo = require("octo.commands")
          local bezlio_team = {
            "pgarcia3pillar",
            "rgarcia3pillar",
            "victorqnk",
            "3rickgamez",
            "sk8Guerra",
            "eduardomorua",
          }

          for _, value in ipairs(bezlio_team) do
            octo["commands"]["reviewer"]["add"](value)
          end

          print("The Team Bezlio are added as reviwers")
        end,
        desc = "Add Bezlio Reviwers",
      },
    },
  },
}
