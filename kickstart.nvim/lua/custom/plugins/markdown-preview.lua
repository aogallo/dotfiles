-- install with yarn or npm
return {
  "iamcco/markdown-preview.nvim",
  cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
  build = "cd app && yarn install",
  init = function()
    vim.g.mkdp_filetypes = { "markdown" }
  end,
  ft = { "markdown" },
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
