require("nvim-tree").setup()


vim.keymap.set({ "n", "x", "i" }, "<A-1>", "<cmd>NvimTreeFindFile<cr>")
vim.keymap.set({ "n", "x", "i" }, "<A-2>", "<cmd>NvimTreeClose<cr>")

