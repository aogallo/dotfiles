return {
  'lewis6991/gitsigns.nvim',
  opts = {
    numhl = true,
    current_line_blame = true,
    word_diff = true
  },
  keys = {
    {
      '<leader>gj',
      '<plug>(signify-next-hunk)',
      desc = "Next hunk"

    }, {
    '<leader>gk', '<plug>(signify-prev-hunk)', desc = "Prev hunk"

  },
    {
      '<leader>gJ', '9999<leader>gJ', desc = ""

    },
    {
      '<leader>gK', '9999<leader>gk', desc = ""

    }
  }
}
