return {
  "pwntester/octo.nvim",
  keys = {
    -- create a pull request
    { "<leader>gC", "<cmd>Octo pr create<CR>", desc = "Create Pull Request (Octo)" },
    -- set draft pr
    { "<leader>gD", "<cmd>Octo pr draft<cr>", desc = "Send PR to Draft" },
  },
}
