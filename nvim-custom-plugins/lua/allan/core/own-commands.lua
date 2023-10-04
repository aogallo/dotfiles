local M = {}
print('holaaaaaaaaaaaaaaaaaaaaaaa')

M.close_all_buffers = function()
  local bufs = vim.api.nvim_list_bufs()
  local current_buf = vim.api.nvim_get_current_buf()
  for _, i in ipairs(bufs) do
    if i ~= current_buf then
      vim.api.nvim_buf_delete(i, {})
    end
  end
end

M.welcome = function()
  print('hello world')
end

return M
