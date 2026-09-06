vim.g.rustaceanvim = {
  tools = {
    inlay_hints = {
      auto = true,
      show_parameter_hints = false,
      parameter_hints_prefix = "",
      other_hints_prefix = "",
    },
  },
  server = {
    default_settings = {
      -- rust-analyzer language server configuration
      ["rust-analyzer"] = {
        completion = {
          callable = { snippets = "none" },
        },
        cargo = {
          allTargets = false,
          loadOutDirsFromCheck = true,
          runBuildScripts = true,
          features = "all",
        },
        inlayHints = {
          bindingModeHints = { enable = false },
          chainingHints = { enable = true },
          closingBraceHints = { enable = true, minLines = 25 },
          closureReturnTypeHints = { enable = "never" },
          lifetimeElisionHints = { enable = "never", useParameterNames = false },
          maxLength = 25,
          parameterHints = { enable = true },
          reborrowHints = { enable = "never" },
          renderColons = true,
          typeHints = {
            enable = true,
            hideClosureInitialization = false,
            hideNamedConstructor = false,
          },
        },
        -- checkOnSave = false,
        procMacro = {
          enable = true,
          -- ignored = {
          --   ["async-trait"] = { "async_trait" },
          --   ["napi-derive"] = { "napi" },
          --   ["async-recursion"] = { "async_recursion" },
          -- },
        },
      },
    },
  },
}
