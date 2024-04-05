require("mason").setup()
require("mason-lspconfig").setup()

local fn = vim.fn
local keymap = vim.keymap
local diagnostic = vim.diagnostic

local util = require("lspconfig/util")

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

lspconfig.ruff_lsp.setup {
  init_options = {
    settings = {
      -- Any extra CLI arguments for `ruff` go here.
      args = {},
    }
  },
  on_attach = custom_attach,
}


lspconfig.jedi_language_server.setup {
  on_attach = custom_attach,
  capabilities = capabilities,
}

lspconfig.pyright.setup {
  on_attach = custom_attach,
  capabilities = capabilities,
  single_file_support = false,
  settings = {
    python = {
      analysis = {
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
        diagnosticMode = "workspace",
        autoImportCompletions = true,
        indexing = true,
        packageIndexDepth = {
          name = "",
          depth = 3,
        }
      },
    },
  },
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

lspconfig.rust_analyzer.setup {
  on_attach = custom_attach,
  capabilities = capabilities,
  settings = {
    ["rust-analyzer"] = {
      cargo = {
        allFeatures = true,
        loadOutDirsFromCheck = true,
        runBuildScripts = true,
      },
      -- Add clippy lints for Rust.
      checkOnSave = {
        allFeatures = true,
        command = "clippy",
        extraArgs = { "--no-deps" },
      },
      procMacro = {
        enable = true,
        ignored = {
          ["async-trait"] = { "async_trait" },
          ["napi-derive"] = { "napi" },
          ["async-recursion"] = { "async_recursion" },
        },
      },
    },
  }
}

lspconfig.tsserver.setup {
  on_attach = custom_attach,
  capabilities = capabilities,
}

local clangd_capabilities = require('cmp_nvim_lsp').default_capabilities()
clangd_capabilities.offsetEncoding = "utf-8"
lspconfig.clangd.setup {
  on_attach = custom_attach,
  capabilities = clangd_capabilities,
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

lspconfig.emmet_language_server.setup({
  on_attach = custom_attach,
  capabilities = capabilities,
  filetypes = { "css", "eruby", "html", "javascript", "javascriptreact", "less", "sass", "scss", "svelte", "pug",
    "typescriptreact", "vue" },
})

lspconfig.svelte.setup {
  on_attach = custom_attach,
  capabilities = capabilities
}

lspconfig.html.setup {
  capabilities = capabilities,
}


lspconfig.tailwindcss.setup {
  on_attach = custom_attach,
  capabilities = capabilities,
}
