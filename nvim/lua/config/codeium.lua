vim.g.codeium_disable_bindings = 1
vim.g.codeium_enabled = true
vim.keymap.set('i', '<C-l>', function () return vim.fn['codeium#Accept']() end, { expr = true, silent = true })
vim.keymap.set('i', '<C-k>', function () return vim.fn['codeium#AcceptNextLine']() end, { expr = true, silent = true })
vim.keymap.set('i', '<C-j>', function () return vim.fn['codeium#AcceptNextWord']() end, { expr = true, silent = true })
vim.keymap.set('i', '<M-]>', function() return vim.fn['codeium#CycleCompletions'](1) end, { expr = true, silent = true })
vim.keymap.set('i', '<M-[>', function() return vim.fn['codeium#CycleCompletions'](-1) end, { expr = true, silent = true })
vim.keymap.set('i', '<C-x>', function() return vim.fn['codeium#Clear']() end, { expr = true, silent = true })

