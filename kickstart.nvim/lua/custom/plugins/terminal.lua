return {
  "NvChad/nvterm",
  keys = {
    {
      "<C-t>",
      function()
        require("nvterm.terminal").toggle("float")
      end,
      desc = "[T]oggle terminal",
      mode = { "n", "t" },
    },
  },
  config = function()
    require("nvterm").setup()
  end,
}
