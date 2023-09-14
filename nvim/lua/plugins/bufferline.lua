return {
  'akinsho/bufferline.nvim',
  version = "*",
  dependencies = 'nvim-tree/nvim-web-devicons',
  config = true,
  opts = {
    options = {
      name_formatter = function(buf)     -- buf contains a "name", "path" and "bufnr"
        -- remove extension from markdown files for example
        if buf.name:match('%.md') then
          return vim.fn.fnamemodify(buf.name, ':t:r')
        end
      end,
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
