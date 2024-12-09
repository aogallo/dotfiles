return {
  "nvim-neotest/neotest",
  dependencies = {
    "nvim-neotest/nvim-nio",
    "nvim-lua/plenary.nvim",
    "antoinemadec/FixCursorHold.nvim",
    "nvim-treesitter/nvim-treesitter",
    "marilari88/neotest-vitest",
  },
  keys = {
    {
      "<leader>cf",
      function()
        require("neotest").run.run(vim.fn.expand("%"))
      end,
      desc = "Run current file",
    },
    {
      "<leader>cs",
      function()
        require("neotest").summary.open()
      end,
      desc = "Test Summary",
    },
    {
      "<leader>cp",
      function()
        require("neotest").output_panel.toggle()
      end,
      desc = "Display [O]utput of Tests",
    },
    {
      "<leader>cu",
      function()
        require("neotest").run.run({ vim.fn.expand("%"), vitestCommand = "vitest --coverage --ui" })
      end,
      desc = "Run current file with ui (NeoVitest)",
    },
  },
  config = function()
    require("neotest").setup({
      adapters = {
        require("neotest-vitest"),
      },
    })
  end,
}
