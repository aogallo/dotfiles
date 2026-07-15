local arrows = require('icons').arrows

-- Set <space> as the leader key
vim.g.mapleader = ' '
vim.g.localmapleader = ' '

-- Use and indentation
vim.o.sw = 2
vim.o.ts = 2
vim.o.et = true

-- Show whitespace
vim.opt.list = true
vim.opt.listchars = { space = '⋅', trail = '⋅', tab = '  ↦' }

vim.wo.number = true
vim.o.relativenumber = true

vim.o.mouse = 'a'

vim.o.linebreak = true

vim.o.mousescroll = 'ver:3,hor:0'

-- Folding
vim.o.foldcolumn = '1'
vim.o.foldlevelstart = 99
vim.wo.foldtext = ''

-- UI characters.
vim.opt.fillchars = {
    eob = ' ',
    fold = ' ',
    foldclose = arrows.right,
    foldopen = arrows.down,
    foldsep = ' ',
    foldinner = ' ',
    msgsep = '─',
}

-- Use rounded borders for flotating windows
vim.o.winborder = 'rounded'

vim.o.clipboard = 'unnamedplus'

vim.o.undofile = true
vim.o.exrc = true

vim.o.ignorecase = true
vim.o.smartcase = true

vim.wo.signcolumn = 'yes'

-- Update times and timeouts
vim.o.updatetime = 300
vim.o.timeoutlen = 500
vim.o.ttimeoutlen = 10

-- Completion
vim.opt.wildignore:append { '.DS_Store' }
vim.o.completeopt = 'menuone,noselect,noinsert'
vim.o.pumheight = 15
vim.o.pumborder = 'rounded'

vim.opt.diffopt:append 'followwrap,vertical,context:99'

vim.opt.shortmess:append {
    w = true,
    s = true,
}

-- Status line
vim.o.laststatus = 3
vim.o.cmdheight = 1

vim.o.guicursor = 'n-v-c-sm:block,i-ci-ve:ver25,r-cr-o:hor20,t:block-TermCursor'

-- Disable health checks for these providers.
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_node_provider = 0
