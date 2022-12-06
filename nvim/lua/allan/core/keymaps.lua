vim.g.mapleader = " "

local keymap = vim.keymap
-- local keymap = vim.api.nvim_set_keymap
local options = { noremap = true, silent = true}

-- general keymaps
keymap.set("i", "jk", "<ESC>", options)
keymap.set("i", "JK", "<ESC>", options)
keymap.set("v", "<leader>JK", "<ESC>", options)
keymap.set("v", "<leader>jk", "<ESC>", options)

-- Save file
keymap.set("n", "<leader>ss", ":w<cr>", options)
keymap.set("i", "<C-s>", "<ESC>:w<cr>", options)

-- Search
keymap.set("n", "<leader>nh", ":nohl<CR>", options)

-- Increment & Decrement
keymap.set("n", "<leader>+", "<C-a>", options)
keymap.set("n", "<leader>-", "<C-x>", options)

-- split window
keymap.set("n", "<leader>sv", "<C-w>v", options) -- vertically
keymap.set("n", "<leader>sh", "<C-w>s", options) -- horizontally
keymap.set("n", "<leader>se", "<C-w>=", options) -- make split windows equeal width
keymap.set("n", "<leader>sx", ":close<CR>", options) -- close current split window

-- tab move
keymap.set("n", "<leader>to", ":tabnew<CR>", options) -- open new tab
keymap.set("n", "<leader>tx", ":tabclose<CR>", options) -- close current tab
keymap.set("n", "<leader>tn", ":tabn<CR>", options) -- go to next tab
keymap.set("n", "<leader>tp", ":tabp<CR>", options) -- go to previous tab

-- Move between screen
keymap.set("n", "<C-l>", "<C-w>l", options)
keymap.set("n", "<C-h>", "<C-w>h", options)
keymap.set("n", "<C-j>", "<C-w>j", options)
keymap.set("n", "<C-k>", "<C-w>k", options)

-- Moves blocks of code in visual mode
keymap.set("x", "U", ":move '<-2<CR>gv-gv", options)
keymap.set("x", "D", ":move '<+1<CR>gv-gv", options)

-- Keep the selected lines in visual mode to add indentetion
keymap.set("v", "<", "<gv", options)
keymap.set("v", ">", ">gv", options)

-- Delete single character without copying into register
keymap.set("n", "x", '"_x', options)

-- Go to end line in insert mode
keymap.set("i", "<C-e>", "<C-o>$", options)


---------------------
-- Plugin Keybinds
---------------------

-- vim-maximizer
keymap.set("n", "<leader>sm", ":MaximizerToggle<CR>", options)
