call plug#begin("$XDG_CONFIG_HOME/nvim/plugged")
    Plug 'chrisbra/csv.vim'
    Plug 'tpope/vim-unimpaired'
    Plug 'junegunn/fzf'
    Plug 'tpope/vim-dispatch'
call plug#end()

"use system clipboard in vim
set clipboard+=unnamedplus

noremap <Up> <Nop>
noremap <Down> <Nop>
noremap <Left> <Nop>
noremap <Right> <Nop>

nnoremap <C-j> <C-d>
"clear search highlights with <C-l>
nnoremap <silent> <C-l> :nohlsearch<CR><C-l>
"invoke fuzzy file finder with <C-p>"
nnoremap <C-p> :<C-u>FZF<CR>

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

set wildmenu
set wildmode=full

set mouse=a

colo zellner

augroup filetype_csv
    autocmd!
    autocmd BufRead,BufWritePost *.csv :%ArrangeColumn!
    autocmd BufWritePre *.csv :%UnArrangeColumn
augroup END
