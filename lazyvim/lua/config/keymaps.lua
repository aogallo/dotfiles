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

-- Go to end line in insert mode
vim.keymap.set("i", "<C-e>", "<C-o>$")
