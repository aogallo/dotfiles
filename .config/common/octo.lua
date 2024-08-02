return {
	{
		"pwntester/octo.nvim",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-telescope/telescope.nvim",
			"nvim-tree/nvim-web-devicons",
		},
		config = function()
			require("octo").setup({ enable_builtin = true })
			vim.cmd([[hi OctoEditable guibg=noe]])
		end,
		keys = {
			-- create a pull request
			{ "<leader>go", "<cmd>Octo pr create<CR>", desc = "Create Pull Request (Octo)" },
			-- set draft pr
			{ "<leader>gD", "<cmd>Octo pr draft<cr>", desc = "Send PR to Draft (Octo)" },
			-- open pull request in browser
			{ "<leader>ga", "<cmd>Octo pr browser<cr>", desc = "Open PR in browser (Octo)" },
			-- copy pr url to clipboard
			{ "<leader>gu", "<cmd>Octo pr url<cr>", desc = "Copy PR URL (Octo)" },
			--  add bezlio reviwers
			{
				"<leader>vb",
				function()
					local octo = require("octo.commands")
					local bezlio_team = {
						"pgarcia3pillar",
						"rgarcia3pillar",
						"victorqnk",
						"3rickgamez",
						"sk8Guerra",
						"eduardomorua",
					}

					for _, value in ipairs(bezlio_team) do
						octo["commands"]["reviewer"]["add"](value)
					end

					-- octo["commands"]["reviewer"]["add"]("rgarcia3pillar")
					-- octo["commands"]["reviewer"]["add"]("victorqnk")
					-- octo["commands"]["reviewer"]["add"]("3rickgamez")
					-- octo["commands"]["reviewer"]["add"]("sk8Guerra")
					-- octo["commands"]["reviewer"]["add"]("eduardomorua")

					print("The Team Bezlio are added as reviwers")
				end,
				desc = "Add Bezlio Reviwers",
			},
		},
	},
}
