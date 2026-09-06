local M = {}

-- Native LSP config name -> Mason package. Activation and installation share this list.
M.servers = {
  buf_ls = "buf",
  clangd = "clangd",
  gopls = "gopls",
  html = "html-lsp",
  jsonls = "json-lsp",
  kotlin_lsp = "kotlin-lsp",
  lua_ls = "lua-language-server",
  ruff = "ruff",
  svelte = "svelte-language-server",
  tailwindcss = "tailwindcss-language-server",
  ty = "ty",
}

-- Conform formatter -> package and filetypes. Ruff serves both LSP and formatting.
M.formatters = {
  stylua = { package = "stylua", filetypes = { "lua" } },
  ruff_format = { package = "ruff", filetypes = { "python" } },
  prettier = {
    package = "prettier",
    filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact", "css", "html" },
  },
}

-- Language plugins start these servers themselves; DAP uses the debugger binaries.
M.extra_packages = { "rust-analyzer", "typescript-language-server", "codelldb", "delve" }

function M.formatters_by_ft()
  local result = {}
  for name, formatter in pairs(M.formatters) do
    for _, ft in ipairs(formatter.filetypes) do
      result[ft] = { name }
    end
  end
  return result
end

function M.packages()
  local packages = {}
  for _, name in pairs(M.servers) do
    packages[name] = true
  end
  for _, formatter in pairs(M.formatters) do
    packages[formatter.package] = true
  end
  for _, name in ipairs(M.extra_packages) do
    packages[name] = true
  end
  local result = vim.tbl_keys(packages)
  table.sort(result)
  return result
end

function M.install()
  local installed = require("mason-registry").get_installed_package_names()
  local missing = vim.tbl_filter(function(name)
    return not vim.tbl_contains(installed, name)
  end, M.packages())
  if #missing == 0 then
    vim.notify("All declared Mason tools are installed.", vim.log.levels.INFO)
    return
  end
  -- Mason owns registry refresh, installation, progress, and error reporting.
  vim.cmd.MasonInstall({ args = missing })
end

return M
