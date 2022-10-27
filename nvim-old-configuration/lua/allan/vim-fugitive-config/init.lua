local map = vim.api.nvim_set_keymap

local options = { noremap = true, silent = true}

map('n', '<leader>gg', ':G <cr>', options)
map('n', '<leader>gp', ':G pull<cr>', options)
map('n', '<leader>gs', ':G status<cr>', options)
