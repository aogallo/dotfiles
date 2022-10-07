require('Comment').setup{

  pre_hook = function(ctx)
    if vim.bo.filetype == 'typescriptreact' then
      local U = require('Comment.utils')

      local type = ctx.ctype == U.ctype.linewise and '__default' or '__multiline'

      local location = nil

      if ctx.ctype == U.ctype.blockwise then
        location = require('ts_context_commentstring.utils').get_cursor_location()
      elseif ctx.cmotion == U.cmotion.v or ctx.cmotion == U.cmotion.V then
        location = require('ts_context_commentstring.utils').get_visual_start_location()
      end

      return require('ts_context_commentstring.internal').calculate_commentstring({
        key = type,
        location = location,
      })
    end
  end,
}


-- Normal mode
-- `gcc` - Toggles the current line using linewise comment
-- `gbc` - Toggles the current line using blockwise comment
-- `[count]gcc` - Toggles the number of line given as a prefix-count using linewise
-- `[count]gbc` - Toggles the number of line given as a prefix-count using blockwise
-- `gc[count]{motion}` - (Op-pending) Toggles the region using linewise comment
-- `gb[count]{motion}` - (Op-pending) Toggles the region using blockwise Comment
--
-- Visual mode
-- `gc` - Toggles the region using linewise comment
-- `gb` - Toggles the region using blockwise comment
