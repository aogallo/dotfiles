vim.keymap.set('i', 'jk', '<esc>')

-- Remap for dealing with word wrap and adding jumps to the jumplist.
vim.keymap.set('n', 'j', [[(v:count > 1 ? 'm`' . v:count : 'g') . 'j']], { expr = true })
vim.keymap.set('n', 'k', [[(v:count > 1 ? 'm`' . v:count : 'g') . 'k']], { expr = true })

-- paste over selection without losing yanked text
vim.keymap.set('x', 'p', [["_dP]])

vim.keymap.set('n', '<leader>cd', vim.diagnostic.open_float, { silent = true, desc = 'Diagnostics' })

-- Keeping the cursor centered.
vim.keymap.set('n', '<C-d>', '<C-d>zz', { desc = 'Scroll downwards' })
vim.keymap.set('n', '<C-u>', '<C-u>zz', { desc = 'Scroll upwards' })
vim.keymap.set('n', 'n', 'nzzzv', { desc = 'Next result' })
vim.keymap.set('n', 'N', 'Nzzzv', { desc = 'Previous result' })

-- Indent while remaining in visual mode.
vim.keymap.set('v', '<', '<gv')
vim.keymap.set('v', '>', '>gv')

--buffers
vim.keymap.set('n', '<leader>bn', ':bnext<CR>', { desc = 'Next buffer', silent = true })
vim.keymap.set('n', '<leader>bp', ':bprev<CR>', { desc = 'Previous buffer', silent = true })

-- Formatting.
vim.keymap.set('n', '<leader>cf', 'mzgggqG`z<cmd>delmarks z<cr>zz', { desc = 'Format buffer' })

-- Switch between windows.
vim.keymap.set('n', '<C-h>', '<C-w>h', { desc = 'Move to the left window', remap = true })
vim.keymap.set('n', '<C-j>', '<C-w>j', { desc = 'Move to the bottom window', remap = true })
vim.keymap.set('n', '<C-k>', '<C-w>k', { desc = 'Move to the top window', remap = true })
vim.keymap.set('n', '<C-l>', '<C-w>l', { desc = 'Move to the right window', remap = false })

-- Powerful <esc>
vim.keymap.set({ 'i', 's', 'n' }, '<esc>', function()
    local ok, luasnip = pcall(require, 'luasnip')
    if ok and luasnip.expand_or_jumpable() then
        luasnip.unlink_current()
    end

    vim.cmd 'noh'
    return '<esc>'
end, { desc = 'Escape, clear hlsearch, and stop snippet session', expr = true })

-- Switch between windows.
vim.keymap.set('n', '<leader>pu', '<cmd>packupdate<cr>', { desc = 'Update packages' })
vim.keymap.set('n', '<leader>pl', '<cmd>packupdate ++lockfile<cr>', { desc = 'Sync packages to lockfile' })
