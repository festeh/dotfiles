-- Run from the config directory: nvim --headless -u NONE -i NONE -l tests/tools.lua
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root)
local tools = require("config.tools")
local installed, installs, message = {}, {}, nil
package.loaded["mason-registry"] = {
  get_installed_package_names = function()
    return installed
  end,
}
vim.api.nvim_create_user_command("MasonInstall", function(args)
  installs[#installs + 1] = args.fargs
end, { nargs = "+" })
vim.notify = function(value)
  message = value
end

-- Ruff is required by two consumers but must be installed only once.
tools.install()
local packages = tools.packages()
assert(vim.deep_equal(installs[1], packages))
assert(#vim.tbl_filter(function(name)
  return name == "ruff"
end, packages) == 1)
assert(vim.tbl_contains(packages, "codelldb") and vim.tbl_contains(packages, "delve"))

-- Re-running installation skips installed tools; it does not upgrade them.
installed = packages
tools.install()
assert(#installs == 1 and message:find("All declared", 1, true))
installed = vim.tbl_filter(function(name)
  return name ~= "ruff"
end, packages)
tools.install()
assert(vim.deep_equal(installs[2], { "ruff" }))

local formatters = tools.formatters_by_ft()
assert(vim.deep_equal(formatters.python, { "ruff_format" }))
assert(vim.deep_equal(formatters.lua, { "stylua" }))
for _, ft in ipairs({
  "javascript",
  "javascriptreact",
  "typescript",
  "typescriptreact",
  "css",
  "html",
}) do
  assert(vim.deep_equal(formatters[ft], { "prettier" }))
end
print("Tool declaration checks passed")
