local api = vim.api

local modules = {
  "globals.lua",
  "options.lua",
  "mappings.lua",
  "plugins.lua",
  "themes.lua",
}

local config_dir = vim.fn.stdpath("config")
if vim.g.started_by_firenvim ~= true then
  for _, module in ipairs(modules) do
    local cmd = string.format("source %s/core/%s", config_dir, module)
    api.nvim_exec(cmd, false)
  end
else
  -- local packer = require("packer")
  -- packer.startup {
  --   function(use)
  --     use {
  --       'glacambre/firenvim',
  --       run = function() vim.fn['firenvim#install'](0) end
  --     }
  --   end
  -- }
end
