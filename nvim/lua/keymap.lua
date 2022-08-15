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

-- Better window navigation
keymap("n", "<C-h>", "<C-w>h", opts)
keymap("n", "<C-j>", "<C-w>j", opts)
keymap("n", "<C-k>", "<C-w>k", opts)
keymap("n", "<C-l>", "<C-w>l", opts)

-- Visual --
-- Stay in indent mode
keymap("v", "<", "<gv", opts)
keymap("v", ">", ">gv", opts)

-- Move text up and down
keymap("v", "<A-j>", ":m .+1<CR>==", opts)
keymap("v", "<A-k>", ":m .-2<CR>==", opts)

keymap("v", "p", '"_dP', opts)

-- Visual Block -- Move text up and down
keymap("x", "J", ":move '>+1<CR>gv-gv", opts)
keymap("x", "K", ":move '<-2<CR>gv-gv", opts)
keymap("x", "<A-j>", ":move '>+1<CR>gv-gv", opts)
keymap("x", "<A-k>", ":move '<-2<CR>gv-gv", opts)

-- Navigate buffers
keymap("n", "<S-l>", ":bnext<CR>", opts)
keymap("n", "<S-h>", ":bprevious<CR>", opts)

Total_map("<Right>", "<Nop>")
Total_map("<Left>", "<Nop>")
Total_map("<Up>", "<Nop>")
Total_map("<Down>", "<Nop>")

-- Save on Ctrl+s
keymap("n", "<C-s>", ":update<CR><ESC>", opts)
keymap("i" , "<C-s>", "<C-o>:update<CR><ESC>", opts)
keymap("v" , "<C-s>", "<C-c>:update<CR><ESC>", opts)

-- Git popup
keymap("n", "<C-k>", ":Git<CR>", opts)

vim.keymap.set({"n", "v"}, "K", vim.lsp.buf.hover, opts)
