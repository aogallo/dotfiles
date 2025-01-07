-- lazy.nvim
return {
  "folke/snacks.nvim",
  keys = {
    {
      ";bd",
      function()
        Snacks.bufdelete()
      end,
      desc = "Delete Buffer",
    },
    {
      ";bo",
      function()
        Snacks.bufdelete.other()
      end,
      desc = "Delete all buffers except the current one",
    },
    {
      "<C-t>",
      function()
        Snacks.terminal.toggle()
      end,
      desc = "[T]oggle terminal",
      mode = { "n", "t" },
    },
  },
  opts = {
    terminal = {
      -- your terminal configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
      win = { style = "terminal" },
    },
    dashboard = {},
  },
}
