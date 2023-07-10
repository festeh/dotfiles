local fn = vim.fn
local keymap = vim.keymap
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
  -- map("n", "K", vim.lsp.buf.hover)
  -- map("n", "<C-k>", vim.lsp.buf.signature_help)
  map("n", "<leader>rn", vim.lsp.buf.rename, { desc = "varialbe rename" })
  map("n", "gr", vim.lsp.buf.references, { desc = "show references" })
  map("n", "[d", diagnostic.goto_prev, { desc = "previous diagnostic" })
  map("n", "]d", diagnostic.goto_next, { desc = "next diagnostic" })
  map("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "LSP code action" })
  map("n", "<leader>wa", vim.lsp.buf.add_workspace_folder, { desc = "add workspace folder" })
  map("n", "<leader>wr", vim.lsp.buf.remove_workspace_folder, { desc = "remove workspace folder" })
  map("n", "<leader>wl",
    function()
      vim.inspect(vim.lsp.buf.list_workspace_folders())
    end, { desc = "list workspace folder" })
end

local capabilities = require('cmp_nvim_lsp').default_capabilities()

local lspconfig = require("lspconfig")
-- lspconfig.pyright.setup {
--     on_attach = custom_attach,
--     capabilities = capabilities,
-- }

-- lspconfig.pylsp.setup {
--   -- configurationSources = { "flake8" },
--   on_attach = custom_attach,
--   settings = {
--     pylsp = {
--       plugins = {
--         -- pylint          = { enabled = true, executable = "pylint" },
--         -- pyflakes        = { enabled = false },
--         -- pycodestyle     = { enabled = false },
--         -- mccabe          = { enabled = false },
--         jedi_completion = { fuzzy = true },
--         -- pyls_isort      = { enabled = true },
--         -- pylsp_mypy      = { enabled = true },
--         yapf            = { enabled = true },
--         ruff            = { enabled = true },
--         python_lsp_ruff = { enabled = true },
--       },
--     },
--   },
--   flags = {
--     debounce_text_changes = 200,
--   },
--   capabilities = capabilities,
-- }
lspconfig.ruff_lsp.setup {
  init_options = {
    settings = {
      -- Any extra CLI arguments for `ruff` go here.
      args = {},
    }
  },
  on_attach = custom_attach,
}

lspconfig.pyright.setup {
  single_file_support = false,
  on_attach = custom_attach,
}

lspconfig.lua_ls.setup {
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
          -- fn.stdpath("data") .. "/site/pack/packer/opt/emmylua-nvim",
          fn.stdpath("config"),
        },
        maxPreload = 2000,
        preloadFileSize = 50000,
        checkThirdParty = false,
      },
      telemetry = {
        enable = false,
      },
      single_file_support = false,
    },
  },
  capabilities = capabilities,
}

-- lspconfig.rust_analyzer.setup {
--   on_attach = custom_attach,
--   capabilities = capabilities
-- }

lspconfig.tsserver.setup {
  on_attach = custom_attach,
  capabilities = capabilities,
}

lspconfig.clangd.setup {
  on_attach = custom_attach,
  capabilities = capabilities,
  filetypes = { "c", "cpp", "objc", "objcpp", "cuda", }
}

lspconfig.bufls.setup {
  on_attach = custom_attach,
  capabilities = capabilities
}

lspconfig.gopls.setup {
  on_attach = custom_attach,
  capabilities = capabilities
}

lspconfig.emmet_ls.setup({
    on_attach = custom_attach,
    capabilities = capabilities,
    filetypes = { "css", "eruby", "html", "javascript", "javascriptreact", "less", "sass", "scss", "svelte", "pug", "typescriptreact", "vue" },
    init_options = {
      html = {
        options = {
          -- For possible options, see: https://github.com/emmetio/emmet/blob/master/src/config.ts#L79-L267
          ["bem.enabled"] = true,
        },
      },
    }
})
