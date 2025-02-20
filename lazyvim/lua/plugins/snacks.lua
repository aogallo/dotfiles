-- lazy.nvim
return {
  "folke/snacks.nvim",
  keys = {
    {
      ";;",
      function()
        Snacks.image.hover()
      end,
      desc = "Show Image",
      mode = { "n" },
    },
  },
  opts = {
    image = {
      enabled = true,
      inline = false,
    },
  },
}
