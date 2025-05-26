local keymap = vim.keymap
local diagnostic = vim.diagnostic

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
    on_attach = function(client, bufnr)
      local map = function(mode, l, r, opts)
        opts = opts or {}
        opts.silent = true
        opts.buffer = bufnr
        keymap.set(mode, l, r, opts)
      end
      map(
        "n",
        "K",
        function()
          vim.cmd.RustLsp({ 'hover', 'actions' })
        end
      )
      map("n", "gd", vim.lsp.buf.definition, { desc = "go to definition" })
      -- map("n", "<C-k>", vim.lsp.buf.signature_help)
      map("n", "<leader>rn", vim.lsp.buf.rename, { desc = "varialbe rename" })
      map("n", "gr", vim.lsp.buf.references, { desc = "show references" })
      -- map("n", "[d", diagnostic.goto_prev, { desc = "previous diagnostic" })
      -- map("n", "]d", diagnostic.goto_next, { desc = "next diagnostic" })
      map("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "LSP code action" })
    end,
    default_settings = {
      -- rust-analyzer language server configuration
      ['rust-analyzer'] = {
        cargo = {
          allTargets = false,
          loadOutDirsFromCheck = true,
          runBuildScripts = true,
          features = "all",
        },
        checkOnSave = false,
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
  -- DAP configuration
  dap = {
  },
}
