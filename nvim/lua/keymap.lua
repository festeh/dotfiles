local opts = { noremap = true, silent = true }

local term_opts = { silent = true }

-- Shorten function name
local keymap = vim.api.nvim_set_keymap

function Total_map(key, value)
   keymap("n", key, value, opts)
   keymap("i", key, value, opts)
   keymap("v", key, value, opts)
   keymap("x", key, value, opts)
   keymap("t", key, value, opts)
end

--Remap space as leader key
keymap("", "<Space>", "<Nop>", opts)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Visual Block -- Move text up and down
keymap("x", "J", ":move '>+1<CR>gv-gv", opts)
keymap("x", "K", ":move '<-2<CR>gv-gv", opts)
keymap("x", "<A-j>", ":move '>+1<CR>gv-gv", opts)
keymap("x", "<A-k>", ":move '<-2<CR>gv-gv", opts)

Total_map("<Right>", "<Nop>")
Total_map("<Left>", "<Nop>")
Total_map("<Up>", "<Nop>")
Total_map("<Down>", "<Nop>")

-- Save on Ctrl+s
keymap("n", "<C-s>", ":update<CR>", opts)
keymap("i" , "<C-s>", "<C-o>:update<CR>", opts)
keymap("v" , "<C-s>", "<C-c>:update<CR>", opts)




