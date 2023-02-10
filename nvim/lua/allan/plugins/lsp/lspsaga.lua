local status, saga = pcall(require, "lspsaga")

if not status then
 return
end

saga.init_lsp_saga({
  code_action_icon = ' ',
  move_in_saga = {
    prev = "<C-k>",
    next = "<C-j>"
  },
  finder_action_keys = {
    open = "<CR>"
  },
  definition_action_keys = {
    edit = "<CR>"
  }
})
