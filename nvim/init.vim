 call plug#begin("$XDG_CONFIG_HOME/nvim/plugged")
    Plug 'doums/darcula'
    Plug 'windwp/nvim-autopairs'
    Plug 'vim-test/vim-test'
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
    Plug 'nvim-lualine/lualine.nvim'
    Plug 'neovim/nvim-lspconfig'
    Plug 'williamboman/mason.nvim'
    Plug 'unblevable/quick-scope'
    Plug 'lewis6991/gitsigns.nvim'
    Plug 'numToStr/Comment.nvim'
    Plug 'nvim-lua/plenary.nvim'
    Plug 'sindrets/diffview.nvim'
    Plug 'TimUntersberger/neogit'
    Plug 'phaazon/hop.nvim'
    Plug 'hrsh7th/vim-searchx'
    Plug 'jose-elias-alvarez/null-ls.nvim'
    Plug 'ms-jpq/coq_nvim', {'branch': 'coq'}
    Plug 'ms-jpq/coq.artifacts', {'branch': 'artifacts'}
    Plug 'ms-jpq/coq.thirdparty', {'branch': '3p'}
    Plug 'ms-jpq/chadtree', {'branch': 'chad', 'do': 'python3 -m chadtree deps'}
    Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries' }
    Plug 'nvim-treesitter/nvim-treesitter', { 'do' : ':TSUpdate'}
call plug#end()

" TODO: refactor!
" Overwrite / and ?.
nnoremap ? <Cmd>call searchx#start({ 'dir': 0 })<CR>
nnoremap / <Cmd>call searchx#start({ 'dir': 1 })<CR>
xnoremap ? <Cmd>call searchx#start({ 'dir': 0 })<CR>
xnoremap / <Cmd>call searchx#start({ 'dir': 1 })<CR>
cnoremap ; <Cmd>call searchx#select()<CR>

" Move to next/prev match.
nnoremap N <Cmd>call searchx#prev_dir()<CR>
nnoremap n <Cmd>call searchx#next_dir()<CR>
xnoremap N <Cmd>call searchx#prev_dir()<CR>
xnoremap n <Cmd>call searchx#next_dir()<CR>
nnoremap <C-k> <Cmd>call searchx#prev()<CR>
nnoremap <C-j> <Cmd>call searchx#next()<CR>
xnoremap <C-k> <Cmd>call searchx#prev()<CR>
xnoremap <C-j> <Cmd>call searchx#next()<CR>
cnoremap <C-k> <Cmd>call searchx#prev()<CR>
cnoremap <C-j> <Cmd>call searchx#next()<CR>

let g:searchx = {}

" Auto jump if the recent input matches to any marker.
let g:searchx.auto_accept = v:true

" The scrolloff value for moving to next/prev.
let g:searchx.scrolloff = &scrolloff

" To enable scrolling animation.
" let g:searchx.scrolltime = 500

" To enable auto nohlsearch after cursor is moved
let g:searchx.nohlsearch = {}
let g:searchx.nohlsearch.jump = v:true

" Marker characters.
let g:searchx.markers = split('ABCDEFGHIJKLMNOPQRSTUVWXYZ', '.\zs')

" Convert search pattern.
function g:searchx.convert(input) abort
  if a:input !~# '\k'
    return '\V' .. a:input
  endif
  return a:input[0] .. substitute(a:input[1:], '\\\@<! ', '.\\{-}', 'g')
endfunction

lua << EOF
modules = {
    'keymap', 
    'options', 
    'utils',
    'plugins.gitsigns',
    'plugins.mason',
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
    'plugins.lualine',
    'plugins.autopairs',
    'plugins.tests',
    'plugins.null-ls',
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


nnoremap <A-1> :CHADopen<CR>
inoremap <A-1> <ESC>:CHADopen<CR>

