return {
  'navarasu/onedark.nvim',
  config = function(plugin)
    --print(vim.inspect(plugin))
    vim.cmd("colorscheme onedark")
  end
}
