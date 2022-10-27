local M = {} 

function M.get_icon_state()
	local show_icons = vim.g.lua_tree_show_icons or { git = 1, folders = 1, files = 1}
	local icons = {
		default = "",
		symlink = "",
		folder_icons = {
			default = "🥺",
		}
	} 
end

require'nvim-tree'.setup{
  view = {
    relativenumber = false,
    adaptive_size = true,
    mappings = {
      list = {
        { key = "u", action = "dir_up" }
      }
    },
  },
  filters = {
    dotfiles = false,
    custom = {
      '^.env$'
    }
  }
--	log = {
-- enable = true,
--  truncate = true,
--  types = {
--    git = true,
--    profile = true,
--  },
-- },
}
