return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      -- add tsx and treesitter
      opts.auto_install = true

      vim.list_extend(opts.ensure_installed, {
        "astro",
        "css",
        "typescript",
        "graphql",
        "tsx",
        "norg",
        "rust",
        "markdown_inline",
        "markdown",
      })

      vim.list_extend(opts.incremental_selection, {
        enable = true,
        keymaps = {
          init_selection = "<C-space>",
          node_incremental = "<C-space>",
          scope_incremental = false,
          node_decremental = "<bs>",
        },
      })

      vim.list_extend(opts.textobjects, {
        move = {
          enable = true,
          goto_next_start = { ["]f"] = "@function.outer", ["]c"] = "@class.outer" },
          goto_next_end = { ["]F"] = "@function.outer", ["]C"] = "@class.outer" },
          goto_previous_start = { ["[f"] = "@function.outer", ["[c"] = "@class.outer" },
          goto_previous_end = { ["[F"] = "@function.outer", ["[C"] = "@class.outer" },
        },
      })
    end,
  },
}
