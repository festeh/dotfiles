local diagnostic = vim.diagnostic
local keymap = vim.keymap

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
  -- require('navigator.lspclient.mapping').setup({ bufnr = bufnr, client = client })
end

require("flutter-tools").setup {
  dev_log = {
    enabled = true,
    notify_errors = true,
    open_cmd = "tabedit",
  },
  lsp = {
    on_attach = custom_attach,
  },
  flutter_lookup_cmd = "asdf where flutter",
}
