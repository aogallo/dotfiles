local status, lualine = pcall(require, "lualine")
if not status then
  return
end

local lualine_nightfly = require("lualine.themes.nightfly")
local new_colors = {
  blue = "#65D1FF",
  green = "#3EFFDC",
  violet = "#FF61EF",
  yellow = "#FFDA7B",
  balck = "#00000"
}

lualine_nightfly.normal.a.bg = new_colors.blue
lualine_nightfly.insert.a.bg = new_colors.green
lualine_nightfly.visual.a.bg = new_colors.violet
lualine_nightfly.command = {
  a = {
    gui = "bold",
    bg = new_colors.yellow,
    fg = new_colors.balck,
  }
}

lualine.setup{
	options = {
		icons_enabled = true,
    theme = lualine_nightfly
	},
  extensions = {
    'nvim-tree',
    'fugitive'
  },
  component_separators = { left = '', right = '' },
	section_separatos = { left = '', right = ''},
	sections = {
		lualine_a = {'mode'},
		lualine_b = {'branch'},
		lualine_c = {
			{
				'filename',
				path = 0,
			}
		},
    lualine_x = {
      {
        'diagnostics',
        sources = {"nvim_lsp"},
        symbols = {
          error = ' ',
          warn = ' ',
          info = ' ',
          hint = ' '
        }
      },
        'encoding',
        'filetype'
    },
		-- lualine_y = {'%=', '%t%m', '%3p'},
		lualine_z = {'location'},
	},
  winbar = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = {
      {
      'filename',
      path = 1,
      fmt = function(str) return str:gsub('/', '  ') end
    }
    },
    lualine_x = {},
    lualine_y = {},
    lualine_z = {}
  },
--   tabline = {
--   lualine_a = {},
--   lualine_b = {'branch'},
--   lualine_c = {'filename'},
--   lualine_x = {},
--   lualine_y = {},
--   lualine_z = {}
-- },
  inactive_sections = {

  lualine_a = {},
  lualine_b = {},
  lualine_c = {'filename'},
  lualine_x = {'location'},
  lualine_y = {},
  lualine_z = {}
  },
	show_modified_status = true
}

