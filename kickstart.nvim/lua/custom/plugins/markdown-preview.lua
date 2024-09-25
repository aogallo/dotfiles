-- install without yarn or npm
return {
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
}
