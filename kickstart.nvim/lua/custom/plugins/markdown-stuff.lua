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
    opts = {
      preset = "obsidian", -- lazy | obsidian
      heading = {
        position = "inline",
      },
    },
    -- dependencies = { "nvim-treesitter/nvim-treesitter", "echasnovski/mini.nvim" }, -- if you use the mini.nvim suite
    -- dependencies = { 'nvim-treesitter/nvim-treesitter', 'echasnovski/mini.icons' }, -- if you use standalone mini plugins
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" }, -- if you prefer nvim-web-devicons
  },
}
