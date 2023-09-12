return {
  'akinsho/bufferline.nvim',
  version = "*",
  dependencies = 'nvim-tree/nvim-web-devicons',
  config = true,
  opts = {
    options = {
      allways_show_bufferline = true,
      close_command = "bdelete %",
      color_icons = true,
      diagnostics = "nvim_lsp",
      diagnostics_indicator = function(count, level)
        local icon = level:match("error") and " " or ""
        return " " .. icon .. count
      end,
      numbers = "ordinal",
      offsets = {
        {
          filetype = "NvimTree",
          text = "Explorer",
          padding = 1,
          separtor = true
        }
      }
    }
  }
}
