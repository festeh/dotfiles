local fn = vim.fn
local keymap = vim.keymap
local lspconfig = require("lspconfig")
local diagnostic = vim.diagnostic


require("neodev").setup({
  -- add any options here, or leave empty to use the default settings
})

local custom_attach = function(client, bufnr)
    local map = function(mode, l, r, opts)
        opts = opts or {}
        opts.silent = true
        opts.buffer = bufnr
        keymap.set(mode, l, r, opts)
    end

    map("n", "gd", vim.lsp.buf.definition, { desc = "go to definition" })
    map("n", "<C-]>", vim.lsp.buf.definition)
    map("n", "K", vim.lsp.buf.hover)
    -- map("n", "<C-k>", vim.lsp.buf.signature_help)
    map("n", "<leader>rn", vim.lsp.buf.rename, { desc = "varialbe rename" })
    map("n", "gr", vim.lsp.buf.references, { desc = "show references" })
    map("n", "[d", diagnostic.goto_prev, { desc = "previous diagnostic" })
    map("n", "]d", diagnostic.goto_next, { desc = "next diagnostic" })
    map("n", "<leader>q", diagnostic.setqflist, { desc = "put diagnostic to qf" })
    map("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "LSP code action" })
    map("n", "<leader>wa", vim.lsp.buf.add_workspace_folder, { desc = "add workspace folder" })
    map("n", "<leader>wr", vim.lsp.buf.remove_workspace_folder, { desc = "remove workspace folder" })
    map("n", "<leader>wl",
        function()
            vim.inspect(vim.lsp.buf.list_workspace_folders())
        end, { desc = "list workspace folder" })

    -- Set some key bindings conditional on server capabilities
    if client.server_capabilities.documentFormattingProvider then
        map("n", "<leader>m", vim.lsp.buf.format, { desc = "format code" })
    end
end

local capabilities = require('cmp_nvim_lsp').default_capabilities()

lspconfig.pylsp.setup {
    on_attach = custom_attach,
    settings = {
        pylsp = {
            plugins = {
                pylint = { enabled = true, executable = "pylint" },
                pyflakes = { enabled = false },
                pycodestyle = { enabled = false },
                jedi_completion = { fuzzy = true },
                pyls_isort = { enabled = true },
                pylsp_mypy = { enabled = true },
            },
        },
    },
    flags = {
        debounce_text_changes = 200,
    },
    capabilities = capabilities,
}


lspconfig.sumneko_lua.setup {
    on_attach = custom_attach,
    settings = {
        Lua = {
            runtime = {
                -- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
                version = "LuaJIT",
            },
            diagnostics = {
                -- Get the language server to recognize the `vim` global
                globals = { "vim" },
            },
            workspace = {
                -- Make the server aware of Neovim runtime files,
                -- see also https://github.com/sumneko/lua-language-server/wiki/Libraries#link-to-workspace .
                -- Lua-dev.nvim also has similar settings for sumneko lua, https://github.com/folke/lua-dev.nvim/blob/main/lua/lua-dev/sumneko.lua .
                library = {
                    fn.stdpath("data") .. "/site/pack/packer/opt/emmylua-nvim",
                    fn.stdpath("config"),
                },
                maxPreload = 2000,
                preloadFileSize = 50000,
            },
        },
    },
    capabilities = capabilities,
}

lspconfig.rust_analyzer.setup{
    on_attach = custom_attach,
    capabilities=capabilities
}
