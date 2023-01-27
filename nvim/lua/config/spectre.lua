require("spectre").setup {
    open_cmd = "vnew"
}

vim.keymap.set("n", "<leader>s", "<cmd>lua require('spectre').open_file_search()<CR>")
vim.keymap.set("n", "<leader>S", "<cmd>lua require('spectre').open()<CR>")
