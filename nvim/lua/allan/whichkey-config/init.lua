local wk = require('which-key')

local mappings = {
	f = { 
				":Telescope find_files<cr>",
				"Telescope Find Files"
			},
	l = {
				":Telescope live_grep<cr>",
				"Telescope Live Grep"
			}
}

local opts = {
	prefix = '<leader>'
}

wk.register(mappings, opts)
