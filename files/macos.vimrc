"Disable compatibility with vi wich can cause unecpected isues
set nocompatible

"Don't save backups files
set nobackup

"Do not wrap lines
set nowrap

set ruler
set ignorecase
set smartcase
set number
set mouse=a
set numberwidth=1
set clipboard=unnamed
syntax enable
set showcmd
set encoding=utf-8
set showmatch
set sw=2
set relativenumber
set laststatus=2
set cursorline
set list lcs=tab:\|\
set encoding=UTF-8
set ts=4 sw=4 et

"Use highlightingwhen doing a serch
set hlsearch

"Set the commands to save in histori default number is 20
set history=1000

"Enable plugins and load plugin for the detected file type
filetype plugin on

"Load an indent tile for the detected file type
filetype indent on

set omnifunc=syntaxcomplete#Complete

"Plugins
call plug#begin('~/.vim/plugged')

Plug 'morhetz/gruvbox'
Plug 'dense-analysis/ale'
Plug 'preservim/nerdtree'
Plug 'neoclide/coc.nvim', {'branch':'release'}
Plug 'vim-python/python-syntax'
Plug 'kaicataldo/material.vim'
Plug 'nathanaelkane/vim-indent-guides'
Plug 'Xuyuanp/nerdtree-git-plugin'
Plug 'ryanoasis/vim-devicons'

call plug#end()

"Mapping keys
inoremap jk <ESC>

nnoremap Y y$

" Open NerdTree
map <C-n> :NERDTreeToggle<CR>

"Open terminal
map <F2> :b
call plug#end()

"Mapping keys
inoremap jk <ESC>

nnoremap Y y$

" Open NerdTree
map <C-n> :NERDTreeToggle<CR>

"Open terminal
map <F2> :belowright terminal<CR>

"Split windows writtin :split or :vsplit
nnoremap <c-j> <c-w>j
nnoremap <c-k> <c-w>k
nnoremap <c-h> <c-w>h
nnoremap <c-l> <c-w>l


"Resize windows
noremap <c-up> <c-w>+
noremap <c-down> <c-w>-
noremap <c-left> <c-w>>
noremap <c-right> <c-w><

"Indent Configuration
let g:indent_guides_start_level = 2
let g:indennt_guides_guide_size = 1

"Configuration github symbols nerdtree
let g:NERDTreeGitStatusIndicatorMapCustom = {
                \ 'Modified'  :'✹',
                \ 'Staged'    :'✚',
                \ 'Untracked' :'✭',
                \ 'Renamed'   :'➜',
                \ 'Unmerged'  :'═',
                \ 'Deleted'   :'✖',
                \ 'Dirty'     :'✗',
                \ 'Ignored'   :'☒',
                \ 'Clean'     :'✔︎',
                \ 'Unknown'   :'?',
                \ }
