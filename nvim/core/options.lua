local o = vim.o
local wo = vim.wo
local fn = vim.fn

o.swapfile = false
o.number = true -- line numbers
o.mouse = "a" -- enable mouse in all modes
o.termguicolors = true
o.tabstop=2       -- number of visual spaces per TAB
o.softtabstop=2   -- number of spaces in tab when editing
o.shiftwidth=2    -- number of spaces to use for autoindent
o.expandtab=true -- expand tab to spaces so that tabs are spaces
o.breakindent = true
o.ignorecase = true
o.smartcase = true
o.autowrite=true -- save file on buf change and make
o.clipboard="unnamedplus" -- share system clipboard with vim
o.cursorline=true
o.undofile=true
o.undodir=fn.stdpath("data").."/undo"
o.undolevels=5000
o.splitright = true
o.splitbelow = true

o.updatetime = 100

o.signcolumn = "yes"
o.jumpoptions = "stack"

o.exrc = true
