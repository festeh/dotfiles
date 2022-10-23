local js = vim.api.nvim_create_augroup("JS", { clear = true })
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" },
                            { pattern = "*.js", group = js, command = "set sts=2 sw=2 ts=2" })
