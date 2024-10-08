-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

vim.keymap.set("i", "jk", "<ESC>", { desc = "Go to normal mode" })
vim.keymap.set("i", "JK", "<ESC>", { desc = "Go to normal mode" })

vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

vim.keymap.set("n", "<C-a>", "gg<S-v>G", { desc = "Select all" })

-- Delete single character without copying into register
vim.keymap.set("n", "x", '"_x')

-- use `+` and `-` to increment and decrement 8
vim.keymap.set("n", "+", "<C-a>")
vim.keymap.set("n", "-", "<C-x>")
vim.keymap.set("v", "+", "g<C-a>gv")
vim.keymap.set("v", "-", "g<C-x>gv")

vim.keymap.set("t", "<esc><esc>", "<c-\\><c-n>")

-- Open a terminal at the bottom of the screen with a fixed height.
vim.keymap.set("n", ",st", function()
  vim.cmd.new()
  vim.cmd.wincmd("J")
  vim.api.nvim_win_set_height(0, 12)
  vim.wo.winfixheight = true
  vim.cmd.term()
end)

vim.keymap.set("n", "<leader>j", function()
  -- local buffer = vim.api.nvim_get_current_buf()
  vim.cmd([[%s/\\n/\r/g]])
  vim.cmd([[%s/\\"/"/g]])

  -- vim.api.
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local buffer_content = table.concat(lines, "\n")

  local found = string.find(buffer_content, "\\", 1, true)
  if found ~= nil then
    vim.cmd([[%s/\\\\/\\/g]])
  end

  vim.cmd([[nohlsearch]])
end, {
  desc = "Format jq filter",
})
