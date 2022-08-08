local wk = require('which-key')

local mappings = {
	f = { 
				":Telescope find_files<cr>",
				"Telescope Find Files"
			},
	l = {
		name = 'LSP',
		i = {":LspInfo<cr>", "Connect Language Server"},
		A = {"<cmd>lua vim.lsp.buf.add_workspace_folder<CR>", 'Add workspace folder'},
		R = {"<cmd>lua vim.lsp.buf.remove_workspace_folder<CR>", 'Remove workspace folder'},
		l = {"<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>", 'List workspace folder'},
		D = {"<cmd>lua vim.lsp.buf.type_definition()<CR>", 'Type definition'},
		r = {"<cmd>lua vim.lsp.buf.rename()<CR>", 'Rename'},
		a = {"<cmd>lua vim.lsp.buf.code_actions()<CR>", 'Code actions'},
		e = {"<cmd>lua vim.lsp.diagnostic.show_line_diagnostics()<CR>", 'Show line diagnostics'},
		q = {"<cmd>lua vim.lsp.diagnostic.set_loclist()<CR>", 'Show loclist'},
	},
	E = {
		":e ~/.config/nvim/init.vim<cr> :e ~/.config/nvim/lua/allan/init.lua<CR>",
		"Edit/Reload config Vim/Neovim"
	}
}

local opts = {
	prefix = '<leader>'
}

wk.register(mappings, opts)
