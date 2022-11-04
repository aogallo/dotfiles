vim.g.mapleader = " "

local keymap = vim.keymap

-- general keymaps
keymap.set("i", "jk", "<ESC>")
keymap.set("i", "jk", "<ESC>")
keymap.set("n", "JK", "<ESC>")
keymap.set("n", "jk", "<ESC>")
keymap.set("v", "JK", "<ESC>")
keymap.set("v", "jk", "<ESC>")

-- Save file
keymap.set("n", "<leader>ss", ":w<cr>", options)
keymap.set("i", "<C-s>", "<ESC>:w<cr>", options)

-- Search
keymap.set("n", "<leader>nh", ":nohl<CR>")

-- Increment & Decrement
keymap.set("n", "<leader>+", "<C-a>")
keymap.set("n", "<leader>-", "<C-x>")

-- split window
keymap.set("n", "<leader>sv", "<C-w>v") -- vertically
keymap.set("n", "<leader>sh", "<C-w>s") -- horizontally
keymap.set("n", "<leader>se", "<C-w>=") -- make split windows equeal width
keymap.set("n", "<leader>sx", ":close<CR>") -- close current split window

-- tab move
keymap.set("n", "<leader>to", ":tabnew<CR>") -- open new tab
keymap.set("n", "<leader>tx", ":tabclose<CR>") -- close current tab
keymap.set("n", "<leader>tn", ":tabn<CR>") -- go to next tab
keymap.set("n", "<leader>tp", ":tabp<CR>") -- go to previous tab

-- Move between screen
keymap.set("n", "<C-l>", "<C-w>l", options)
keymap.set("n", "<C-h>", "<C-w>h", options)
keymap.set("n", "<C-j>", "<C-w>j", options)
keymap.set("n", "<C-k>", "<C-w>k", options)

-- Moves blocks of code in visual mode
keymap.set("x", "u", ":move '<-2<CR>gv-gv", options)
keymap.set("x", "d", ":move '<+1<CR>gv-gv", options)

-- indentetion
keymap.set("v", "<", "<gv", options)
keymap.set("v", ">", ">gv", options)
