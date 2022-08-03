call plug#begin("$XDG_CONFIG_HOME/nvim/plugged")
    Plug 'doums/darcula'
    Plug 'chrisbra/csv.vim'
    Plug 'tpope/vim-unimpaired'
    Plug 'junegunn/fzf'
    Plug 'tpope/vim-dispatch'
    Plug 'mbbill/undotree'
    Plug 'tpope/vim-fugitive'
    Plug 'tpope/vim-commentary'
    Plug 'tpope/vim-surround'
    Plug 'itchyny/lightline.vim'
    Plug 'neovim/nvim-lspconfig'
    Plug 'unblevable/quick-scope'
    Plug 'justinmk/vim-sneak'
    Plug 'ms-jpq/coq_nvim', {'branch': 'coq'}
    Plug 'ms-jpq/coq.artifacts', {'branch': 'artifacts'}
    Plug 'ms-jpq/coq.thirdparty', {'branch': '3p'}
    Plug 'ms-jpq/chadtree', {'branch': 'chad', 'do': 'python3 -m chadtree deps'}
    Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries' }
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
"reload config 
nnoremap <Leader>r :lua ReloadConfig()<CR> \| :source $MYVIMRC<CR>

colorscheme darcula


augroup filetype_csv
    autocmd!
    autocmd BufRead,BufWritePost *.csv :%ArrangeColumn!
    autocmd BufWritePre *.csv :%UnArrangeColumn
augroup END
" TODO: refactor into plugin settings
let g:lightline = {
      \ 'colorscheme': 'one',
      \ }
let g:sneak#label = 1
let g:sneak#use_ic_scs = 1

nnoremap <A-1> :CHADopen<CR>
inoremap <A-1> <ESC>:CHADopen<CR>

lua << EOF
local ok, res = pcall(require, 'plugins.lspinit')
local ok, res = pcall(require, 'plugins.quick-scope')
local ok, res = pcall(require, 'options')
local ok, res = pcall(require, 'utils')
if not ok then
    print(res)
    end
EOF
