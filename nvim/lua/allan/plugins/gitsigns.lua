local status, gitsigns = pcall(require, "gitsigns")
if not status then
  return
end

gitsigns.setup({
  current_line_blame = true,
  numhl = true
})

local keymap = vim.keymap

keymap.set('n', '<leader>gj', '<plug>(signify-next-hunk)', options)
keymap.set('n', '<leader>gk', '<plug>(signify-prev-hunk)', options)
keymap.set('n', '<leader>gJ', '9999<leader>gJ', options)
keymap.set('n', '<leader>gK', '9999<leader>gk', options)
