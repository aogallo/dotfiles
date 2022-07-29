require('bufferline').setup {
  options = {
    numbers = "ordinal",
    close_command = "bdelete! %d",       -- can be a string | function, see "Mouse actions"
    right_mouse_command = "bdelete! %d", -- can be a string | function, see "Mouse actions"
    left_mouse_command = "buffer %d",    -- can be a string | function, see "Mouse actions"
    middle_mouse_command = nil,          -- can be a string | function, see "Mouse actions"
    indicator_icon = '▎',
    buffer_close_icon = '❌',
    modified_icon = '●',
    close_icon = '🚫',
    right_trunc_marker = '',
    name_formatter = function(buf)  -- buf contains a "name", "path" and "bufnr"
      -- remove extension from markdown files for example
      if buf.name:match('%.md') then
        return vim.fn.fnamemodify(buf.name, ':t:r')
      end
    end,
    max_name_length = 18,
    max_prefix_length = 15, -- prefix used when a buffer is de-duplicated
    tab_size = 18,
    diagnostics = "nvim_lsp" ,
    diagnostics_update_in_insert = false,
    diagnostics_indicator = function(count, level, diagnostics_dict, context)
      return "("..count..")"
    end,
    custom_filter = function(buf_number, buf_numbers)
      -- filter out filetypes you don't want to see
      if vim.bo[buf_number].filetype ~= "<i-dont-want-to-see-this>" then
        return true
      end
      -- filter out by buffer name
      if vim.fn.bufname(buf_number) ~= "<buffer-name-I-dont-want>" then
        return true
      end
      -- filter out based on arbitrary rules
      -- e.g. filter out vim wiki buffer from tabline in your work repo
      if vim.fn.getcwd() == "<work-repo>" and vim.bo[buf_number].filetype ~= "wiki" then
        return true
      end
      -- filter out by it's index number in list (don't show first buffer)
      if buf_numbers[1] ~= buf_number then
        return true
      end
    end,
    offsets = {{filetype = "NvimTree", text = "File Explorer" , text_align = "left" }},
    color_icons = true , -- whether or not to add the filetype icon highlights
    show_buffer_icons = true , -- disable filetype icons for buffers
    show_buffer_close_icons = true ,
    show_buffer_default_icon = true , -- whether or not an unrecognised filetype should show a default icon
    show_close_icon = true ,
    show_tab_indicators = true ,
    persist_buffer_sort = true, -- whether or not custom sorted buffers should persist
    -- can also be a table containing 2 custom separators
    -- [focused and unfocused]. eg: { '|', '|' }
    separator_style = "slant" ,
    enforce_regular_tabs = true,
    always_show_bufferline = false,
  }
}


vim.cmd[[
	nnoremap <silent><TAB> :BufferLineCycleNext<CR>
	nnoremap <silent><S-TAB> :BufferLineCyclePrev<CR>
	nnoremap <silent><leader>1 <Cmd>BufferLineGoToBuffer 1<CR>
	nnoremap <silent><leader>2 <Cmd>BufferLineGoToBuffer 2<CR>
	nnoremap <silent><leader>3 <Cmd>BufferLineGoToBuffer 3<CR>
	nnoremap <silent><leader>4 <Cmd>BufferLineGoToBuffer 4<CR>
	nnoremap <silent><leader>5 <Cmd>BufferLineGoToBuffer 5<CR>
	nnoremap <silent><leader>6 <Cmd>BufferLineGoToBuffer 6<CR>
	nnoremap <silent><leader>7 <Cmd>BufferLineGoToBuffer 7<CR>
	nnoremap <silent><leader>8 <Cmd>BufferLineGoToBuffer 8<CR>
	nnoremap <silent><leader>9 <Cmd>BufferLineGoToBuffer 9<CR>
]]
