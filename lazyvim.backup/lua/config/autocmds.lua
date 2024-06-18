-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here
-- vim.api.nvim_create_autocmd("BufWritePre", {
--   pattern = "*",
--   callback = function(args)
--     require("conform").format({ bufnr = args.buf })
--   end,
-- })

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "json", "jsonc" },
  callback = function()
    vim.wo.spell = false
    vim.wo.conceallevel = 0
  end,
})

-- remove
vim.api.nvim_create_autocmd({
  "BufWritePre",
}, {
  pattern = { "*" },
  command = [[%s/\s\+$//e]],
  -- command = "echo 'Out'",
  -- callback = function(ev)
  --   -- print(string.format('event fired: s', vim.inspect(ev)))
  --   -- print(vim.inspect(ev))

  --   vim.command([[%s/\s\+$//e]])
  -- end
})
