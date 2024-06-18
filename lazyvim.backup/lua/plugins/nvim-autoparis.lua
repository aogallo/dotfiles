return {
  "windwp/nvim-autopairs",
  event = "InsertEnter",
  opts = {}, -- this is equalent to setup({}) function
  config = function()
    require("nvim-autopairs").setup({
      ignored_next_char = "[%w%.]", -- will ignore alphanumeric and `.` symbol
    })
  end,
}
