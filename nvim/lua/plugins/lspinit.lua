local lsp = require "lspconfig"
local coq = require "coq"
local util = require "lspconfig/util"

require("coq_3p") {
    { src = "nvimlua", short_name = "nLUA", conf_only = false },
}

---@diagnostic disable-next-line: unused-local
local on_attach = function(client, bufnr)
    if client.resolved_capabilities.document_highlight then
        local hl = vim.api.nvim_set_hl
        local opts = { ctermbg = 240, bg = '#585858' }
        hl(0, 'LspReferenceRead', opts)
        hl(0, 'LspReferenceText', opts)
        hl(0, 'LspReferenceWrite', opts)
        vim.api.nvim_create_augroup('lsp_document_highlight', {})
        vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
            group = 'lsp_document_highlight',
            buffer = 0,
            callback = vim.lsp.buf.document_highlight,
        })
        vim.api.nvim_create_autocmd('CursorMoved', {
            group = 'lsp_document_highlight',
            buffer = 0,
            callback = vim.lsp.buf.clear_references,
        })
    end
end


local lua_settings = {
    Lua = {
        runtime = {
            -- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
            version = 'LuaJIT',
        },
        diagnostics = {
            -- Get the language server to recognize the `vim` global
            globals = { 'vim' },
        },
        -- Do not send telemetry data containing a randomized but unique identifier
        telemetry = {
            enable = false,
        },
    }
}

lsp.sumneko_lua.setup(coq.lsp_ensure_capabilities({
    on_attach = on_attach,
    settings = lua_settings
}))

lsp.gopls.setup(coq.lsp_ensure_capabilities({
    filetypes = { "go", "gomod" },
    root_dir = util.root_pattern("go.work", "go.mod", ".git"),
    settings = {
        gopls = {
            analyses = {
                unusedparams = true,
            },
            staticcheck = true,
        },
    },
}))

vim.api.nvim_set_keymap("n", "<leader>rn", "<cmd>lua vim.lsp.buf.rename()<CR>", { noremap = true })


vim.cmd("COQnow")
