vim.g.mapleader = " "

local keymap = vim.keymap
-- local keymap = vim.api.nvim_set_keymap
local options = { noremap = true, silent = true }

-- general keymaps
keymap.set("i", "jk", "<ESC>", options)
keymap.set("i", "JK", "<ESC>", options)
keymap.set("v", "<leader>JK", "<ESC>", options)
keymap.set("v", "<leader>jk", "<ESC>", options)

-- Save file
keymap.set("n", "<leader>w", ":lua vim.lsp.buf.format {async=true}<cr> :w<cr>", options)
keymap.set("i", "<C-s>", "<ESC>:w<cr>", options)

-- Search
keymap.set("n", "<leader>h", ":nohl<CR>", options)

-- Increment & Decrement
keymap.set("n", "+", "<C-a>", options)
keymap.set("n", "-", "<C-x>", options)

-- Select all
keymap.set("n", "<C-a>", "gg<S-v>G", options)

-- split window
keymap.set("n", "<leader>sv", "<C-w>v", options)     -- vertically
keymap.set("n", "<leader>sh", "<C-w>s", options)     -- horizontally
keymap.set("n", "<leader>se", "<C-w>=", options)     -- make split windows equeal width
keymap.set("n", "<leader>sx", ":close<CR>", options) -- close current split window

-- tab move
keymap.set("n", "<leader>to", ":tabnew<CR>", options)   -- open new tab
keymap.set("n", "<leader>tx", ":tabclose<CR>", options) -- close current tab
keymap.set("n", "<leader>tn", ":tabn<CR>", options)     -- go to next tab
keymap.set("n", "<leader>tp", ":tabp<CR>", options)     -- go to previous tab

-- Move between screen
keymap.set("n", "<C-l>", "<C-w>l", options)
keymap.set("n", "<C-h>", "<C-w>h", options)
keymap.set("n", "<C-j>", "<C-w>j", options)
keymap.set("n", "<C-k>", "<C-w>k", options)

-- Terminal mode
keymap.set("t", "jk", "<C-\\><C-n>", options)
keymap.set("t", "JK", "<C-\\><C-n>", options)

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
-- go to the end line and insert new line
keymap.set("i", "<C-x>", "<esc>o", options)

--Format file
keymap.set("v", "<leader>fm", ":lua vim.lsp.buf.format()", options)


---------------------
-- Plugin Keybinds
---------------------

-- vim-maximizer
--keymap.set("n", "<leader>sm", ":MaximizerToggle<CR>", options)

-- bufferline
keymap.set("n", "<leader>1", "<Cmd>BufferLineGoToBuffer 1<CR>", options)
keymap.set("n", "<leader>2", "<Cmd>BufferLineGoToBuffer 2<CR>", options)
keymap.set("n", "<leader>3", "<Cmd>BufferLineGoToBuffer 3<CR>", options)
keymap.set("n", "<leader>4", "<Cmd>BufferLineGoToBuffer 4<CR>", options)
keymap.set("n", "<leader>5", "<Cmd>BufferLineGoToBuffer 5<CR>", options)
keymap.set("n", "<leader>6", "<Cmd>BufferLineGoToBuffer 6<CR>", options)
keymap.set("n", "<leader>7", "<Cmd>BufferLineGoToBuffer 7<CR>", options)
keymap.set("n", "<leader>8", "<Cmd>BufferLineGoToBuffer 8<CR>", options)
keymap.set("n", "<leader>9", "<Cmd>BufferLineGoToBuffer 9<CR>", options)
keymap.set("n", "<leader>$", "<Cmd>BufferLineGoToBuffer -1<CR>", options)


-- L3MON4D3/LuaSnip
keymap.set("i", "<c-j>", "<cmd>lua require'luasnip'.jump(1)<CR>", options)
keymap.set("s", "<c-j>", "<cmd>lua require'luasnip'.jump(1)<CR>", options)
keymap.set("i", "<c-k>", "<cmd>lua require'luasnip'.jump(-1)<CR>", options)
keymap.set("s", "<c-k>", "<cmd>lua require'luasnip'.jump(-1)<CR>", options)
