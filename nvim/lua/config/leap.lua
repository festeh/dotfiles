-- Set up leap.nvim keymaps (replaces deprecated add_default_mappings())
vim.keymap.set({'n', 'x', 'o'}, 's', '<Plug>(leap)')
vim.keymap.set('n', 'S', '<Plug>(leap-from-window)')
