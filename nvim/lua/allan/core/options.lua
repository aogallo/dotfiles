local opt = vim.opt

-- line numbers
opt.relativenumber = true
opt.number = true

-- tabs & indentation
opt.tabstop = 2
opt.shiftwidth = 2
opt.expandtab = true
opt.autoindent = true
opt.mouse = "a"
-- line wrapping
opt.wrap = false

-- search settings
opt.ignorecase = true
opt.smartcase = true


-- cursor line
opt.cursorline = true
opt.cursorcolumn = true

-- appearance
opt.termguicolors = true
opt.background = "dark"
-- opt.background = "light"
opt.signcolumn = "yes"

-- backspace
opt.backspace = "indent,eol,start"

-- clipboard
opt.clipboard:append("unnamedplus")

-- split windows
opt.splitright = true
opt.splitbelow = true

-- add - as word
opt.iskeyword:append("-")

opt.lazyredraw = true

vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
