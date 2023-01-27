local api = vim.api

local modules = {
  "globals.lua",
  "options.lua",
  "mappings.lua",
  "plugins.lua",
  "themes.lua",
}

local config_dir = vim.fn.stdpath("config")

for _, module in ipairs(modules) do
  local cmd = string.format("source %s/core/%s", config_dir, module)
  api.nvim_exec(cmd, false)
end

