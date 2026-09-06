-- Run from the config directory: nvim --headless -u NONE -i NONE -l tests/lsp.lua
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root)
vim.g.mapleader = " "
package.loaded["blink.cmp"] = {
  get_lsp_capabilities = function(overrides)
    return overrides
  end,
}
local enabled
vim.lsp.enable = function(servers)
  enabled = servers
end
local lsp = require("config.lsp")
lsp.setup()
lsp.setup()
assert(#vim.api.nvim_get_autocmds({ group = "ConfigLsp", event = "LspAttach" }) == 1)
assert(vim.tbl_contains(enabled, "ruff") and vim.tbl_contains(enabled, "ty"))
assert(not vim.tbl_contains(enabled, "rust_analyzer"), "Rustacean owns Rust activation")
assert(not lsp.capabilities().textDocument.completion.completionItem.snippetSupport)

local function attach(buf)
  vim.api.nvim_exec_autocmds(
    "LspAttach",
    { group = "ConfigLsp", buffer = buf, data = { client_id = 1 } }
  )
end
local function map(buf, lhs)
  return vim.api.nvim_buf_call(buf, function()
    return vim.fn.maparg(lhs, "n", false, true)
  end)
end
local first = vim.api.nvim_get_current_buf()
attach(first)
assert(map(first, "gd").callback == vim.lsp.buf.definition)
assert(map(first, "<C-k>").callback == vim.lsp.buf.signature_help)
assert(map(first, "<leader>wa").callback == vim.lsp.buf.add_workspace_folder)
assert(map(first, "<leader>wr").callback == vim.lsp.buf.remove_workspace_folder)
assert(map(first, "gr").lhs == nil, "Use native grr without shadowing its prefix")

-- A second client must not reinstall mappings or overwrite later buffer customizations.
vim.keymap.set("n", "gd", "<cmd>echo 'custom'<cr>", { buffer = first })
attach(first)
assert(map(first, "gd").rhs:find("custom", 1, true))
local second = vim.api.nvim_create_buf(true, false)
attach(second)
assert(map(second, "gd").callback == vim.lsp.buf.definition)

-- The shared hover action chooses Rust actions at invocation time, not attachment order.
local hovered, rust_args, message = 0, nil, nil
local get_clients = vim.lsp.get_clients
vim.lsp.buf.hover = function()
  hovered = hovered + 1
end
vim.lsp.get_clients = function()
  return {}
end
map(first, "K").callback()
assert(hovered == 1)
vim.api.nvim_create_user_command("RustLsp", function(args)
  rust_args = args.fargs
end, { nargs = "*" })
vim.lsp.get_clients = function()
  return { { name = "rust-analyzer" } }
end
map(first, "K").callback()
assert(vim.deep_equal(rust_args, { "hover", "actions" }) and hovered == 1)
vim.lsp.buf.list_workspace_folders = function()
  return { "/project" }
end
vim.notify = function(value)
  message = value
end
map(first, "<leader>wl").callback()
assert(message:find("/project", 1, true), "Workspace listing must actually display its result")
vim.lsp.get_clients = get_clients
print("LSP checks passed")
