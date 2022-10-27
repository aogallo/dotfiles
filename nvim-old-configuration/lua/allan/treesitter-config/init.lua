require'nvim-treesitter.configs'.setup {
	ensure_installed = {
												"html",
												"lua",
												'javascript',
												'python',
												'dockerfile',
												'json',
												'graphql',
												'yaml',
												'toml',
												'vim',
												'css',
												'dart',
												'tsx',
												'typescript',
												'markdown',
												'markdown_inline'
										},
	highlight = {
		enable = true,
    disable = {}
		-- additional_vim_regex_highlighting = false,
	},
  indent = {
    enable = false,
    disable = {}
  },
	autotag = {
		enable = true
	},
	rainbow = {
		enable = true,
		extended_mode = false,
		max_file_lines = nil,
	},
	autopairs = {
		enable = true
	}
}
