local status, nvim_tree = pcall(require, 'nvim-tree')

if not status then
  return
end

vim.g.loaded = 1
vim.g.loaded_netrwPlugin = 1

vim.cmd([[ highlight NvimTreeIndentMarker guifg=#3FC5FF]])


local keymap = vim.api.nvim_set_keymap
local options = { noremap = true, silent = true }

nvim_tree.setup {
  renderer = {
		icons = {
			glyphs = {
				folder = {
					arrow_closed = "", -- arrow when folder is closed
					arrow_open = "", -- arrow when folder is open
				},
			},
		},
	},
  filters = {
    dotfiles = false,
    custom = {
      '^.env$'
    }
  },
  log = {
    enable = true,
    truncate = true,
    types = {
      all = false,
      config = false,
      copy_paste = true,
      dev = true,
      diagnostics = false,
      git = true,
      profile = false,
      watcher = false,
    }
  }
}

local function open_nvim_tree (data)
  require("nvim-tree.api").tree.toggle({ focus = false, find_file = true,})
end

vim.api.nvim_create_autocmd({ "VimEnter" }, { callback = open_nvim_tree })

keymap("n", "<leader>e", ":NvimTreeToggle<CR>", options)
