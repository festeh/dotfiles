require('grug-far').setup({
})

vim.keymap.set({ 'n', 'x' }, '<leader>s', function()
  require('grug-far').open({
    prefills = { search = vim.fn.expand("<cword>") },
    extraRgArgs = '-i',
  })
end, { desc = 'grug-far: Search for current word under cursor' })


vim.keymap.set({ 'n', 'x' }, '<leader>S', function()
  require('grug-far').open({
    extraRgArgs = '-i',
  })
end, { desc = 'grug-far: Search globally from scratch' })
