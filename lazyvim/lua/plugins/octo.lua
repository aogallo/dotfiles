return {
  "pwntester/octo.nvim",
  keys = {
    -- create a pull request
    { "<leader>go", "<cmd>Octo pr create<CR>", desc = "Create Pull Request (Octo)" },
    -- set draft pr
    { "<leader>gD", "<cmd>Octo pr draft<cr>", desc = "Send PR to Draft (Octo)" },
    -- open pull request in browser
    { "<leader>ga", "<cmd>Octo pr browser<cr>", desc = "Open PR in browser (Octo)" },
    -- copy pr url to clipboard
    { "<leader>gu", "<cmd>Octo pr url<cr>", desc = "Copy PR URL to clipboard (Octo)" },
  },
}
