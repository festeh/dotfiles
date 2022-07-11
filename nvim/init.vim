call plug#begin("$XDG_CONFIG_HOME/nvim/plugged")
    Plug 'chrisbra/csv.vim'
call plug#end()

"use system clipboard in vim
set clipboard+=unnamedplus

noremap <Up> <Nop>
noremap <Down> <Nop>
noremap <Left> <Nop>
noremap <Right> <Nop>

set noswapfile

set undofile
set undodir=$HOME/.config/nvim/undo
set undolevels=10000
set undolevels=10000

set number

set autoindent 
set expandtab
set tabstop=4
set softtabstop=4 
set shiftwidth=4

set incsearch
set hlsearch

set smartcase "ignorecase, but smart

colo zellner

augroup filetype_csv
    autocmd!
    autocmd BufRead,BufWritePost *.csv :%ArrangeColumn!
    autocmd BufWritePre *.csv :%UnArrangeColumn
augroup END
