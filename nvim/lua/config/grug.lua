local grug = require("grug-far")

grug.setup({
})

local function close_grug()
  if grug.is_instance_open() then
    grug.close_instance()
  end
end

vim.keymap.set({ 'n', 'x' }, '<leader>s', function()
  close_grug()
  grug.open({
    prefills = { search = vim.fn.expand("<cword>") },
    extraRgArgs = '-i',
  })
end, { desc = 'grug-far: Search for current word under cursor' })


vim.keymap.set({ 'n', 'x' }, '<leader>S', function()
  close_grug()
  grug.open({
    extraRgArgs = '-i',
  })
end, { desc = 'grug-far: Search globally from scratch' })
