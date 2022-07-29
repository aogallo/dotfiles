local o = vim.o
local wo = vim.wo
local bo = vim.bo

-- global options
o.swapfile = true
o.dir = '/tmp'
o.smartcase = true
o.laststatus = 2
o.hlsearch = true
o.incsearch = true
o.ignorecase = true
o.scrolloff = 12
o.shortmess = vim.o.shortmess .. 'c'
o.hidden = true
o.whichwrap = 'b,s,<,>,[,],h,l'
o.splitbelow = true
o.splitright = true
o.termguicolors = true
o.mouse = 'a'
o.cursorline = true
o.tabstop = 2
o.softtabstop = 2
o.shiftwidth = 2
o.guifont = "monospace:h17"
o.completeopt = menu

-- window-local options
wo.number = false
wo.wrap = false
wo.number = true
wo.relativenumber = true



-- buffer-local options
bo.expandtab = true
bo.tabstop = 2
bo.shiftwidth = 2
bo.softtabstop = 2

