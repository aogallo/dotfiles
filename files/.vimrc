" Disable compatibility with vi which can cause unexpected issues.
set nocompatible

"Don't save backup files
set nobackup

" Do not wrap lines. Allow long lines to extend as far as the line goes.
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
set tabstop=2

" Use highlighting when doing a search.
set hlsearch

" Set the commands to save in history default number is 20.
set history=1000

" Enable plugins and load plugin for the detected file type.
filetype plugin on

" Load an indent filey for the detected file type
filetype indent on

set omnifunc=syntaxcomplete#Complete

"PLugins
call plug#begin('~/.vim/plugged')

Plug 'morhetz/gruvbox'
Plug 'dense-analysis/ale'
Plug 'preservim/nerdtree'
"Conquer of Completion like VSCode
Plug 'neoclide/coc.nvim', {'branch': 'release'}
"Plug 'easymotion/vim-easymotion'
"Plug 'scrooloose/nerdtree'
"Plug 'nvim-lua/completion-nvim'
"Plug 'Yggdroot/indentLine'
"Plug 'junegunn/fzf', { 'do': { -> fzf#install() }}
"Plug 'junegunn/fzf.vim'
"Plug 'stsewd/fzf-checkout.vim'

"Telescope
"plug 'nvim-lua/popup.nvim'
"Plug 'nvim-lua/plenary.nvim'
"Plug 'nvim-telescope/telescope.nvim'
"Plug 'nvim-telescope/telescope-fzy-native.nvim'

call plug#end()

"Mapping keys
inoremap jk <ESC>

"Yak from cursor to the end of line
nnoremap Y y$

" You can split the window in Vim by typing :split or :vsplit.
" Navigate the split view easier by pressing CTRL+j, CTRL+k, CTRL+h, or CTRL+l.
nnoremap <c-j> <c-w>j
nnoremap <c-k> <c-w>k
nnoremap <c-h> <c-w>h
nnoremap <c-l> <c-w>l

" Resize split windows using arrow keys by pressing:
" CTRL+UP, CTRL+DOWN, CTRL+LEFT, or CTRL+RIGHT.
noremap <c-up> <c-w>+
noremap <c-down> <c-w>-
noremap <c-left> <c-w>>
noremap <c-right> <c-w><

colorscheme gruvbox
set background=dark
let g:gruvbox_contrast_dark="hard"

let g:indentLine_color_term = 239
"let g:indentLine_bgcolor_term = 202
let g:indentLine_bgcolor_gui = '#FF5F00'
let g:indentLine_char_list = ['|', '¦', '┆', '┊']

let g:fzf_layot = { 'window': { 'with': 0.8, 'height': 0.8 } }
let $FZF_DEFAULT_OPTS='--reverse'

"let g:deoplete#enable_at_startup = 1

let mapleader=" "

"nmap <Leader>s <Plug>(easymotion-s2)
nmap <F3> :NERDTreeToggle<CR>

" Check if NERDTree is open or active
function! IsNERDTreeOpen()
  return exists("t:NERDTreeBufName") && (bufwinnr(t:NERDTreeBufName) != -1)
endfunction

" Call NERDTreeFind iff NERDTree is active, current window contains a modifiable
" file, and we're not in vimdiff
function! SyncTree()
  if &modifiable && IsNERDTreeOpen() && strlen(expand('%')) > 0 && !&diff
    NERDTreeFind
    wincmd p
  endif
endfunction

" Highlight currently open buffer in NERDTree
autocmd BufRead * call SyncTree()

" You can split a window into sections by typing `:split` or `:vsplit`.
" Display cursorline and cursorcolumn ONLY in active window.
augroup cursor_off
    autocmd!
    autocmd WinLeave * set nocursorline nocursorcolumn
    autocmd WinEnter * set cursorline cursorcolumn
augroup END

"Normal mode double space to go the command 
nnoremap <space><space> :

"nmap <Leader>gc :GCHeckout<CR>

" STATUS LINE ----------------------------------- {{{

"Clear status line when vimrc is reloaded
set statusline=

"Status line left side
"%F - Display the full path of the current file
"%M - Modified flag show if file is unsaved
"%Y - Type of file in the buffer
"%R - Displays the read-only flag
set statusline+=\ %F\ %M\ %Y\ %R

"Use a divider to seprate the left side from the right side
set statusline+=%=

" Status line right side.
"%b - Shows the ASCII/Unicode character under cursor
"0x%B - Shows the hexadecimal character under cursor
"%1 - Display the row number
"%c - Display the column number
"%p%% - Show the cursor percentage from the top of the file
set statusline+=\ ascii:\ %b\ hex:\ 0x%B\ row:\ %l\ col:\ %c\ percent:\ %p%%

" Show the status on the second to last line.
set laststatus=2


" }}}


"Coc configuartion
let g:coc_global_extensions = [
  \ 'coc-snippets',
  \ 'coc-pairs',
  \ 'coc-tsserver',
  \ 'coc-eslint', 
  \ 'coc-prettier', 
  \ 'coc-json',
	\ 'coc-html',
	\ 'coc-markdownlint',
  \ ]

" Always show the signcolumn, otherwise it would shift the text each time
" diagnostics appear/become resolved.
if has("nvim-0.5.0") || has("patch-8.1.1564")
  " Recently vim can merge signcolumn and number column into one
  set signcolumn=number
else
  set signcolumn=yes
endif


" Use tab for trigger completion with characters ahead and navigate.
" NOTE: Use command ':verbose imap <tab>' to make sure tab is not mapped by
" other plugin before putting this into your config.
inoremap <silent><expr> <TAB>
      \ pumvisible() ? "\<C-n>" :
      \ <SID>check_back_space() ? "\<TAB>" :
      \ coc#refresh()
inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"

function! s:check_back_space() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction

" Use <c-space> to trigger completion.
if has('nvim')
  inoremap <silent><expr> <c-space> coc#refresh()
else
  inoremap <silent><expr> <c-@> coc#refresh()
endif

" Make <CR> auto-select the first completion item and notify coc.nvim to
" format on enter, <cr> could be remapped by other vim plugin
inoremap <silent><expr> <cr> pumvisible() ? coc#_select_confirm()
                              \: "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"

" Use `[g` and `]g` to navigate diagnostics
" Use `:CocDiagnostics` to get all diagnostics of current buffer in location list.
nmap <silent> [g <Plug>(coc-diagnostic-prev)
nmap <silent> ]g <Plug>(coc-diagnostic-next)

" GoTo code navigation.
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)

" Highlight the symbol and its references when holding the cursor.
autocmd CursorHold * silent call CocActionAsync('highlight')

