return {
  { -- You can easily change to a different colorscheme.
    -- Change the name of the colorscheme plugin below, and then
    -- change the command in the config to whatever the name of that colorscheme is.
    --
    -- If you want to see what colorschemes are already installed, you can use `:Telescope colorscheme`.
    "folke/tokyonight.nvim",
    priority = 1000, -- Make sure to load this before all the other start plugins.
    enabled = true,
    init = function()
      -- Load the colorscheme here.
      -- Like many other themes, this one has different styles, and you could load
      -- any other, such as 'tokyonight-storm', 'tokyonight-moon', or 'tokyonight-day'.
      vim.cmd.colorscheme("tokyonight-moon")

      -- You can configure highlights by doing something like:
      vim.cmd.hi("Comment gui=none")
    end,
    opts = {
      transparent = true,
      styles = {
        sidebars = "transparent",
        floats = "transparent",
      },
    },
  },

  {
    -- https://github.com/rebelot/kanagawa.nvim
    "rebelot/kanagawa.nvim", -- You can replace this with your favorite colorscheme
    lazy = false, -- We want the colorscheme to load immediately when starting Neovim
    enabled = false,
    priority = 1000, -- Load the colorscheme before other non-lazy-loaded plugins
    opts = {
      -- Replace this with your scheme-specific settings or remove to use the defaults
      -- transparent = true,
      background = {
        -- light = "lotus",
        dark = "wave", -- "wave, dragon"
      },
    },
    config = function(_, opts)
      require("kanagawa").setup(opts) -- Replace this with your favorite colorscheme
      vim.cmd("colorscheme kanagawa") -- Replace this with your favorite colorscheme
    end,
  },
  {
    "catppuccin/nvim",
    name = "catppuccin",
    enabled = true,
    priority = 1000,
    init = function()
      vim.cmd.colorscheme("catppuccin-mocha")
    end,
  },
}