-- install without yarn or npm
return {
  "iamcco/markdown-preview.nvim",
  cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
  ft = { "markdown" },
  build = function()
    vim.fn["mkdp#util#install"]()
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
