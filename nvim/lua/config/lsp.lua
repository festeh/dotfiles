local M = {}

function M.capabilities()
  return require("blink.cmp").get_lsp_capabilities({
    textDocument = { completion = { completionItem = { snippetSupport = false } } },
  })
end

local function hover()
  if #vim.lsp.get_clients({ bufnr = 0, name = "rust-analyzer" }) > 0 then
    vim.cmd.RustLsp({ "hover", "actions" })
  else
    vim.lsp.buf.hover()
  end
end

local function list_workspaces()
  vim.notify(vim.inspect(vim.lsp.buf.list_workspace_folders()))
end

function M.setup()
  vim.diagnostic.config({ virtual_text = true })
  vim.lsp.inlay_hint.enable(true)
  vim.lsp.config("*", { capabilities = M.capabilities() })

  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("ConfigLsp", { clear = true }),
    callback = function(event)
      -- Multiple servers (e.g. Ruff + ty) share one set of buffer mappings.
      if vim.b[event.buf].config_lsp_keymaps then return end
      vim.b[event.buf].config_lsp_keymaps = true
      for _, mapping in ipairs({
        { "gd", vim.lsp.buf.definition, "Go to definition" },
        { "<C-]>", vim.lsp.buf.definition, "Go to definition" },
        { "K", hover, "LSP hover (Rust actions when available)" },
        { "<C-k>", vim.lsp.buf.signature_help, "Signature help" },
        { "<leader>rn", vim.lsp.buf.rename, "Rename symbol" },
        { "<leader>ca", vim.lsp.buf.code_action, "LSP code action" },
        { "<leader>wa", vim.lsp.buf.add_workspace_folder, "Add workspace folder" },
        { "<leader>wr", vim.lsp.buf.remove_workspace_folder, "Remove workspace folder" },
        { "<leader>wl", list_workspaces, "List workspace folders" },
      }) do
        vim.keymap.set("n", mapping[1], mapping[2], {
          buffer = event.buf,
          silent = true,
          desc = mapping[3],
        })
      end
    end,
  })

  local servers = vim.tbl_keys(require("config.tools").servers)
  table.sort(servers)
  vim.lsp.enable(servers)
end

return M
