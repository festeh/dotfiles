return {
  workspace_required = true,
  settings = {
    Lua = {
      completion = { callSnippet = "Disable", keywordSnippet = "Disable" },
      runtime = { version = "LuaJIT" },
      diagnostics = { globals = { "vim" } },
      workspace = {
        library = { vim.fn.stdpath("config") },
        maxPreload = 2000,
        preloadFileSize = 50000,
        checkThirdParty = false,
      },
      telemetry = { enable = false },
    },
  },
}
