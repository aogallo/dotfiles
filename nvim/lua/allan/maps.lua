-- maps.lua

local map = vim.api.nvim_set_keymap

-- map the leader key
map('n', '<Space>', '', {})
vim.g.mapleader = ' ' -- 'vim.g' sets global variables

local options = { noremap = true, silent = true}

-- Normal Mode
map('n', '<leader><esc>', ':nohlsearch<cr>', options)
map('n', '<leader>n', ':bnext<cr>', options)
map('n', '<leader>p', ':bprev<cr>', options)

--Save file
map('n', '<leader>ss', ':w <cr>', options)

--Insert line
map('n', '<leader><space>u', 'I <cr><UP>', options)

-- Move between screen
map('n', '<C-l>', '<C-w>l', options)
map('n', '<C-h>', '<C-w>h', options)
map('n', '<C-j>', '<C-w>j', options)
map('n', '<C-k>', '<C-w>k', options)

--LSP
-- map('n', 'K', ':lua vim.lsp.buf.hover()<cr>', options)

--Definition
map('n', '<leader>vd', ':lua vim.lsp.buf.definition()<cr>', options)


--Implementation
map('n', '<leader>vi', ':lua vim.lsp.buf.implementation()<cr>', options)
map('n', '<leader>vrn', ':lua vim.lsp.buf.rename()<cr>', options)

-- Nvim tree
map('n', '<leader>e', ':NvimTreeToggle<CR>', options)



--Telescope
map('n', '<leader>ff', '<cmd>Telescope find_files<cr><esc>', options)
map('n', '<leader>fg', '<cmd>Telescope live_grep<cr>', options)
map('n', '<leader>fb', '<cmd>Telescope buffers<cr>', options)
map('n', '<leader>fh', '<cmd>Telescope help_tags<cr>', options)




-- Insert Mode
map('i', 'jk', '<ESC>', options)


-- Visual
-- Move text up and down
map('v', '<A-j>', ':m .+1<CR>==', options)
map('v', '<A-k>', ':m .-2<CR>==', options)
map('v', 'p', '"_dP', options)


-- Terminal Mode
map('t', '<ESC>', '<C-\\><C-n>', options)
map('t', 'jk', '<C-\\><C-n>', options)
map('t', '<C-h>', '<C-\\><C-N><C-w>h', options)
map('t', '<C-k>', '<C-\\><C-N><C-w>k', options)
map('t', '<C-l>', '<C-\\><C-N><C-w>l', options)
map('t', '<C-j>', '<C-\\><C-N><C-w>j', options)


