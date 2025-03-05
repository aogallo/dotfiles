return {
  {
    -- install without yarn or npm
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    ft = { "markdown" },
    build = "cd app && npm install",
    init = function()
      vim.g.mkdp_filetypes = { "markdown" }
    end,
    keys = {
      {
        "<leader>mp",
        "<cmd>MarkdownPreview<cr>",
        desc = "[P]review",
      },
      {
        "<leader>ms",
        "<cmd>MarkdownPreviewStop<cr>",
        desc = "[S]top",
      },
    },
  },
  {
    "MeanderingProgrammer/render-markdown.nvim",
    -- keys = {
    -- {
    --   "<leader>me",
    --   ":RenderMarkdown enable<CR>",
    --   desc = "[E]nable render view",
    -- },
    -- {
    --   "<leader>md",
    --   ":RenderMarkdown disable<CR>",
    --   desc = "[D]isable render view",
    -- },
    -- {
    --   "<leader>mt",
    --   ":RenderMarkdown toggle<CR>",
    --   desc = "[T]oggle render view",
    -- },
    -- },
    opts = {
      enabled = true,
      preset = "obsidian", -- lazy | obsidian
      heading = {
        position = "inline",
      },
      bullet = {
        enabled = true,
        icons = { "●", "○", "◆", "◇" },

        ordered_icons = {},
        left_pad = 0,
        right_pad = 1,
        highlight = "RenderMarkdownBullet",
      },
      html = {
        enabled = true,
        comment = {
          conceal = false,
        },
      },
    },
    -- dependencies = { "nvim-treesitter/nvim-treesitter", "echasnovski/mini.nvim" }, -- if you use the mini.nvim suite
    -- dependencies = { 'nvim-treesitter/nvim-treesitter', 'echasnovski/mini.icons' }, -- if you use standalone mini plugins
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" }, -- if you prefer nvim-web-devicons
  },
  {
    "HakonHarnes/img-clip.nvim",
    event = "VeryLazy",
    opts = {
      -- add options here
      -- or leave it empty to use the default settings
    },
    keys = {
      -- suggested keymap
      { "<leader>p", "<cmd>PasteImage<cr>", desc = "Paste image from system clipboard" },
    },
  },
  {
    "hedyhli/outline.nvim",
    lazy = true,
    cmd = { "Outline", "OutlineOpen" },
    keys = { -- Example mapping to toggle outline
      { "<leader>o", "<cmd>Outline<CR>", desc = "Toggle outline" },
    },
    opts = {
      symbol_folding = {
        autofold_depth = false,
      }, -- Your setup opts here
    },
  },
}
