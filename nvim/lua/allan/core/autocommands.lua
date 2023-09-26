-- Remove whitespaces
vim.api.nvim_create_autocmd(
  {
    "BufWritePre"
  },
  {
    pattern = { "*" },
    command = [[%s/\s\+$//e]],
    -- command = "echo 'Out'",
    -- callback = function(ev)
    --   -- print(string.format('event fired: s', vim.inspect(ev)))
    --   -- print(vim.inspect(ev))

    --   vim.command([[%s/\s\+$//e]])
    -- end

  }
)

-- autocmd BufRead,BufEnter *.astro set filetype=astro
vim.api.nvim_create_autocmd(
  {
    "BufRead",
    "BufEnter"
  },
  {
    pattern = { "*.astro" },
    command = "set filetype=astro"
  }
)
