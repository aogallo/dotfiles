return {
  {
    'akinsho/toggleterm.nvim',
    version = "*",
    opts = { --[[ things you want to change go here]]
      open_mapping = [[<c-\>]],
      start_in_insert = true,
    },
    -- config = function()
    --   vim.keymap.set('t', '<esc>',
    --     [[<C-\><C-n>]], { desc = 'Normal mode in terminal' })
    --   vim.keymap.set(
    --     't',
    --     'jk',
    --     [[<C-\><C-n>]],
    --     { desc = 'Normal mode in terminal' })

    --   vim.keymap.set(
    --     't',
    --     '<C-h>',
    --     [[<Cmd>wincmd h<CR>]],
    --     { desc = 'Move to left from terminal' }
    --   )

    --   vim.keymap.set(
    --     't',
    --     '<C-j>',
    --     [[<Cmd>wincmd j<CR>]],
    --     { desc = 'Move to down from terminal' }
    --   )

    --   vim.keymap.set(
    --     't',
    --     '<C-k>',
    --     [[<Cmd>wincmd k<CR>]],
    --     { desc = 'Move to up from terminal'
    --     })

    --   vim.keymap.set(
    --     't',
    --     '<C-l>',
    --     [[<Cmd>wincmd l<CR>]],
    --     { desc = 'Move to right from terminal'
    --     })
    -- end
  }
}
