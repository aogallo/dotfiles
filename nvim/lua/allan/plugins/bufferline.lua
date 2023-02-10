local status, bufferline = pcall(require, "bufferline")

if not status then
  return
end


bufferline.setup {
  options = {
    allways_show_bufferline = true,
    close_command = "bdelete %",
    color_icons = true,
    diagnostics = "nvim_lsp",
    diagnostics_indicator = function (count, level)
      local icon = level:match("error") and " " or ""
      return " " .. icon .. count
    end,
    mode = "tabs",
    numbers = "buffer_id",
    offsets = {
      {
        filetype = "NvimTree",
        text = "File Explorer",
        padding = 1,
        separator = true
      }
    }
  },
}

