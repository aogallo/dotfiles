-- lazy.nvim
return {
  "folke/snacks.nvim",
  dependencies = {
    {
      "folke/edgy.nvim",
      ---@module 'edgy'
      ---@param opts Edgy.Config
      opts = function(_, opts)
        for _, pos in ipairs({ "top", "bottom", "left", "right" }) do
          opts[pos] = opts[pos] or {}
          table.insert(opts[pos], {
            ft = "snacks_terminal",
            size = { height = 0.4 },
            title = "%{b:snacks_terminal.id}: %{b:term_title}",
            filter = function(_buf, win)
              return vim.w[win].snacks_win
                and vim.w[win].snacks_win.position == pos
                and vim.w[win].snacks_win.relative == "editor"
                and not vim.w[win].trouble_preview
            end,
          })
        end
      end,
    },
  },
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
    {
      "<C-a>",
      function()
        Snacks.terminal.open()
      end,
      mode = { "n", "t" },
      desc = "[O]pen terminal",
    },
    { "<C-h>", "<C-w><C-h>", mode = { "t" }, desc = "Move focus to the left window" },
    { "<C-l>", "<C-w><C-l>", mode = { "t" }, desc = "Move focus to the right window" },
    { "<C-j>", "<C-w><C-j>", mode = { "t" }, desc = "Move focus to the lower window" },
    { "<C-k>", "<C-w><C-k>", mode = { "t" }, desc = "Move focus to the upper window" },
  },
  ---@type snacks.Config
  opts = {
    terminal = {
      -- your terminal configuration comes here
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
      win = { style = "terminal" },
    },
    input = {},
    quickfile = {},
    words = {},
  },
}
