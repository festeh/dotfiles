 call plug#begin("$XDG_CONFIG_HOME/nvim/plugged")
    Plug 'doums/darcula'
    Plug 'sainnhe/everforest'
    Plug 'kyazdani42/nvim-web-devicons'
    Plug 'ggandor/lightspeed.nvim'
    Plug 'nvim-telescope/telescope.nvim', { 'tag': '0.1.0' }
    Plug 'mrjones2014/legendary.nvim'
    Plug 'projekt0n/github-nvim-theme'
    Plug 'chrisbra/csv.vim'
    Plug 'tpope/vim-unimpaired'
    Plug 'junegunn/fzf'
    Plug 'tpope/vim-dispatch'
    Plug 'mbbill/undotree'
    Plug 'stevearc/dressing.nvim'
    Plug 'folke/which-key.nvim'
    Plug 'simnalamburt/vim-mundo'
    Plug 'tpope/vim-surround'
    Plug 'itchyny/lightline.vim'
    Plug 'neovim/nvim-lspconfig'
    Plug 'williamboman/nvim-lsp-installer'
    Plug 'unblevable/quick-scope'
    Plug 'lewis6991/gitsigns.nvim'
    Plug 'numToStr/Comment.nvim'
    Plug 'nvim-lua/plenary.nvim'
    Plug 'sindrets/diffview.nvim'
    Plug 'TimUntersberger/neogit'
    Plug 'phaazon/hop.nvim'
    Plug 'ms-jpq/coq_nvim', {'branch': 'coq'}
    Plug 'ms-jpq/coq.artifacts', {'branch': 'artifacts'}
    Plug 'ms-jpq/coq.thirdparty', {'branch': '3p'}
    Plug 'ms-jpq/chadtree', {'branch': 'chad', 'do': 'python3 -m chadtree deps'}
    Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries' }
    Plug 'nvim-treesitter/nvim-treesitter', { 'do' : ':TSUpdate'}
call plug#end()


lua << EOF
modules = {
    'keymap', 
    'options', 
    'utils',
    'plugins.gitsigns',
    'plugins.quick-scope',
    'plugins.lspinit',
    'plugins.treesitter',
    'plugins.comment',
    'plugins.dressing',
    'plugins.diffview',
    'plugins.neogit',
    'plugins.telescope',
    'plugins.legendary',
    'plugins.whichkey',
    'plugins.hop',
    }
for i, mod in pairs(modules) do 
    local ok, res = pcall(require, mod)
    if not ok then
        print(res)
    end
end
EOF

"clear search highlights with <C-l>
nnoremap <silent> <C-l> :nohlsearch<CR><C-l>
"invoke fuzzy file finder with <C-p>"
nnoremap <C-p> :<C-u>FZF<CR>
"reload config 
nnoremap <Leader>r :lua ReloadConfig()<CR> \| :source $MYVIMRC<CR>

" set background=dark
" let g:everforest_background = 'hard'
" let g:everforest_better_performance = 1
" colorscheme everforest
" colorscheme darcula

" set background="light"
" colorscheme github_dimmed

set background=dark
colorscheme darcula 


augroup filetype_csv
    autocmd!
    autocmd BufRead,BufWritePost *.csv :%ArrangeColumn!
    autocmd BufWritePre *.csv :%UnArrangeColumn
augroup END

" TODO: refactor into plugin settings
let g:lightline = {
      \ 'colorscheme': 'everforest',
      \ }
let g:sneak#label = 1
let g:sneak#use_ic_scs = 1

nnoremap <A-1> :CHADopen<CR>
inoremap <A-1> <ESC>:CHADopen<CR>

