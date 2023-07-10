local g = vim.g


vim.keymap.set("", "<Space>", "<Nop>", { silent = true, noremap = true })
g.mapleader = " "
g.maplocalleader = " "
g.markdown_fenced_languages = { "lua", "python", "rust" }

-- set autocommand 
vim.cmd("autocmd FileType javascript setlocal shiftwidth=2 tabstop=2")
vim.cmd("autocmd FileType javascriptreact setlocal shiftwidth=2 tabstop=2")
vim.cmd("autocmd FileType typescript setlocal shiftwidth=2 tabstop=2")
vim.cmd("autocmd FileType typescriptreact setlocal shiftwidth=2 tabstop=2")
