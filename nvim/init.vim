set background=dark
colorscheme gruvbox 

set guifont=Hack:h14

set fdc=1

set encoding=UTF-8

"-For async update in vim-signify

let g:signify_sign_add = '+'
let g:signify_sign_delete = '-'
let g:signify_sign_delete_first_line = '_'
let g:signify_sign_change = '~'
set updatetime=100

" Lua configurations
lua require('allan')


set cindent shiftwidth=2
