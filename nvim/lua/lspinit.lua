local lsp = require "lspconfig"
vim.g.coq_settings = {["auto_start"] = true}
local coq = require "coq"
local settings = {
    Lua = {
      runtime = {
        -- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
        version = 'LuaJIT',
      },
      diagnostics = {
        -- Get the language server to recognize the `vim` global
        globals = {'vim'},
      },
      -- Do not send telemetry data containing a randomized but unique identifier
      telemetry = {
        enable = false,
  },
}
}

lsp.sumneko_lua.setup(coq.lsp_ensure_capabilities({settings=settings}))
