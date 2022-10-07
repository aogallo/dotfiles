local status, saga = pcall(require, 'lspsaga')
local map = vim.api.nvim_set_keymap
local options = { noremap = true, silent = true}

if not status then return end

saga.init_lsp_saga ()

map('n', '<C-j>', ':Lspsaga diagnostic_jump_next<CR>', options)
map('n', 'K', '<cmd>Lspsaga hover_doc<CR>', options)
map('i', '<C-k>', ':Lspsaga signature_help<CR>', options)
map("n", "gh", "<cmd>Lspsaga lsp_finder<CR>", { silent = true })

-- Code action
-- keymap({"n","v"}, "<leader>ca", "<cmd>Lspsaga code_action<CR>", { silent = true })
local keymap = vim.keymap.set
map('n', "<leader>ca", "<cmd>Lspsaga code_action<CR>", { silent = true })
map('v', "<leader>ca", "<cmd>Lspsaga code_action<CR>", { silent = true })

-- Float terminal
keymap("n", "<A-d>", "<cmd>Lspsaga open_floaterm<CR>", { silent = true })
