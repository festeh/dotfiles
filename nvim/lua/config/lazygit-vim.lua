require('telescope').load_extension('lazygit')
vim.g.lazygit_use_neovim_remote = 0

vim.keymap.set('n', '<leader>l', ':LazyGit<cr>', { noremap = true, silent = true })
