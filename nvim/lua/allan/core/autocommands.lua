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
