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
  }
}

keymap("n", "<leader>e", ":NvimTreeToggle<CR>", options)
