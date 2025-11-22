require("mason").setup()

local fn = vim.fn
local keymap = vim.keymap
local diagnostic = vim.diagnostic

local util = require("lspconfig/util")

-- require("neodev").setup({
-- add any options here, or leave empty to use the default settings
-- })

vim.diagnostic.config({ virtual_text = true })
vim.lsp.inlay_hint.enable(true)

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
  map("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "LSP code action" })
  map("n", "<leader>wl",
    function()
      vim.inspect(vim.lsp.buf.list_workspace_folders())
    end, { desc = "list workspace folder" })
end

local capabilities = vim.tbl_deep_extend(
  "force",
  {},
  vim.lsp.protocol.make_client_capabilities(),
  require("blink.cmp").get_lsp_capabilities()
)

-- Configure Ruff LSP
vim.lsp.config.ruff = {
  init_options = {
    settings = {
      -- Any extra CLI arguments for `ruff` go here.
      args = {},
    }
  },
  on_attach = custom_attach,
}
vim.lsp.enable('ruff')


-- lspconfig.jedi_language_server.setup {
--   on_attach = custom_attach,
--   capabilities = capabilities,
-- }

-- lspconfig.pyright.setup {
--   on_attach = custom_attach,
--   capabilities = capabilities,
--   single_file_support = false,
--   settings = {
--     python = {
--       analysis = {
--         autoSearchPaths = true,
--         useLibraryCodeForTypes = true,
--         diagnosticMode = "workspace",
--         autoImportCompletions = true,
--         indexing = true,
--         packageIndexDepth = {
--           name = "",
--           depth = 3,
--         }
--       },
--     },
--   },
-- }
-- Configure basedpyright LSP
vim.lsp.config.basedpyright = {
  on_attach = custom_attach,
  capabilities = capabilities,
  single_file_support = false,
}
vim.lsp.enable('basedpyright')

-- Configure Lua LSP
vim.lsp.config.lua_ls = {
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
vim.lsp.enable('lua_ls')

-- lspconfig.rust_analyzer.setup {
--   on_attach = custom_attach,
--   capabilities = capabilities,
--   settings = {
--     ["rust-analyzer"] = {
--       cargo = {
--         allTargets = false,
--         loadOutDirsFromCheck = true,
--         runBuildScripts = true,
--         features = "all",
--       },
--       checkOnSave = false,
--       procMacro = {
--         enable = true,
--         -- ignored = {
--         --   ["async-trait"] = { "async_trait" },
--         --   ["napi-derive"] = { "napi" },
--         --   ["async-recursion"] = { "async_recursion" },
--         -- },
--       },
--     },
--   }
-- }

-- lspconfig.tsserver.setup {
--   on_attach = custom_attach,
--   capabilities = capabilities,
--   single_file_support = false,
-- }

-- Configure clangd LSP
-- clone capabilities
local clangd_capabilities = {}
clangd_capabilities.offsetEncoding = "utf-8"
vim.lsp.config.clangd = {
  on_attach = custom_attach,
  capabilities = clangd_capabilities,
  filetypes = { "c", "cpp", "objc", "objcpp", "cuda", }
}
vim.lsp.enable('clangd')

-- Configure buf_ls LSP
vim.lsp.config.buf_ls = {
  on_attach = custom_attach,
  capabilities = capabilities
}
vim.lsp.enable('buf_ls')

-- Configure gopls LSP
vim.lsp.config.gopls = {
  on_attach = custom_attach,
  capabilities = capabilities
}
vim.lsp.enable('gopls')

-- lspconfig.emmet_language_server.setup({
--   on_attach = custom_attach,
--   capabilities = capabilities,
--   filetypes = { "css", "eruby", "html", "javascript", "javascriptreact", "less", "sass", "scss", "svelte", "pug",
--     "typescriptreact", "vue" },
-- })

-- Configure svelte LSP
vim.lsp.config.svelte = {
  on_attach = custom_attach,
  capabilities = capabilities
}
vim.lsp.enable('svelte')

-- Configure HTML LSP
vim.lsp.config.html = {
  capabilities = capabilities,
}
vim.lsp.enable('html')

-- Configure Tailwind CSS LSP
vim.lsp.config.tailwindcss = {
  on_attach = custom_attach,
  capabilities = capabilities,
}
vim.lsp.enable('tailwindcss')

-- Configure Kotlin LSP
vim.lsp.config.kotlin_language_server = {
  on_attach = custom_attach,
  capabilities = capabilities,
}
vim.lsp.enable('kotlin_language_server')

-- Configure JSON LSP
vim.lsp.config.jsonls = {
  on_attach = custom_attach,
  capabilities = capabilities,
  settings = {
    json = {
      schemas = require('schemastore').json.schemas(
        {
          select = {
            "package.json",
            "Chrome Extension",
          }
        }
      ),
      validate = { enable = true },
    },
  },
}
vim.lsp.enable('jsonls')
