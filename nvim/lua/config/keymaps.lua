local keymap = vim.keymap

keymap.set("", "<Space>", "<Nop>", { silent = true })

keymap.set(
  { "n", "i", "x" },
  "<C-s>",
  "<cmd>update!<CR><Esc>",
  { silent = true, noremap = true, desc = "save current buffer" }
)
keymap.set("n", "q:", "<Nop>", { desc = "Doesn't open command history" })

keymap.set("n", "<leader>+", "<C-a>", { desc = "Increment number" })
keymap.set("n", "<leader>-", "<C-x>", { desc = "Decrement number" })

keymap.set("x", "<", "<gv", { desc = "Shift selection left" })
keymap.set("x", ">", ">gv", { desc = "Shift selection right" })

keymap.set("n", "<S-Tab>", "<<", { desc = "Un-tab line" })
keymap.set("i", "<S-Tab>", "<C-d>", { desc = "Un-tab line" })

keymap.set("n", "<leader>q", "<cmd>bd!<CR>", { desc = "Close buffer" })
keymap.set("n", "<leader>x", "<cmd>q<CR>", { desc = "Close window" })

keymap.set("n", "<F11>", "<cmd>set spell!<cr>", { desc = "toggle spell" })
keymap.set("i", "<F11>", "<c-o><cmd>set spell!<cr>", { desc = "toggle spell" })

keymap.set("n", "<leader>d", vim.diagnostic.open_float)
keymap.set("n", "[d", function()
  vim.diagnostic.jump({ count = -1, float = true })
end, { desc = "Previous diagnostic" })
keymap.set("n", "]d", function()
  vim.diagnostic.jump({ count = 1, float = true })
end, { desc = "Next diagnostic" })

keymap.set("n", "<c-v>", '"+p', { noremap = true, silent = true })

-- keymap.set('t', '<Esc>', [[<C-\><C-n>]])
