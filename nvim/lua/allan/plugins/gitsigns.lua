local status, gitsigns = pcall(require, "gitsigns")
if not status then
  return
end

gitsigns.setup()


map('n', '<leader>gj', '<plug>(signify-next-hunk)', options)
map('n', '<leader>gk', '<plug>(signify-prev-hunk)', options)
map('n', '<leader>gJ', '9999<leader>gJ', options)
map('n', '<leader>gK', '9999<leader>gk', options)


