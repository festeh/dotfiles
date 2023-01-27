local g = vim.g


vim.keymap.set("", "<Space>", "<Nop>", { silent = true, noremap = true })
g.mapleader = " "
g.maplocalleader = " "
g.markdown_fenced_languages = { "lua", "python", "rust" }
