-- Run from the config directory: nvim --headless -u NONE -i NONE -l tests/resession.lua
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root)
local loads, saves, pickers = 0, 0, 0
package.loaded.resession = {
  setup = function() end,
  load = function()
    loads = loads + 1
  end,
  save = function()
    saves = saves + 1
  end,
}
package.loaded.snacks = { picker = {
  files = function()
    pickers = pickers + 1
  end,
} }
require("config.resession")

local function enter()
  vim.api.nvim_exec_autocmds("VimEnter", { group = "ConfigResession" })
end
local original_uis, original_argc = vim.api.nvim_list_uis, vim.fn.argc
vim.api.nvim_list_uis = function()
  return {}
end
vim.fn.argc = function()
  return 0
end
enter()
vim.api.nvim_exec_autocmds("VimLeavePre", { group = "ConfigResession" })
assert(loads == 0 and saves == 0 and pickers == 0, "Headless runs must not touch sessions")

vim.api.nvim_list_uis = function()
  return { {} }
end
local buf = vim.api.nvim_get_current_buf()
local scratch = vim.api.nvim_create_buf(false, true)
enter()
assert(pickers == 1, "An empty start buffer should open the picker even with UI scratch buffers")

vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "nonempty" })
vim.bo[buf].modified = false
enter()
assert(pickers == 1, "A nonempty one-line buffer must not open the picker")

vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "" })
vim.bo[buf].modified = false
vim.api.nvim_buf_set_name(buf, "/tmp/nvim-session-test-empty.txt")
enter()
assert(pickers == 1, "A named empty file is not an empty starting buffer")
vim.api.nvim_buf_set_name(buf, "")
local listed = vim.api.nvim_create_buf(true, false)
enter()
assert(pickers == 1, "Other restored buffers must suppress the picker")
vim.api.nvim_buf_delete(listed, { force = true })
vim.api.nvim_buf_delete(scratch, { force = true })
vim.fn.argc = function()
  return 1
end
local previous_loads = loads
enter()
assert(loads == previous_loads, "Explicit file arguments must suppress session restore")
vim.api.nvim_exec_autocmds("VimLeavePre", { group = "ConfigResession" })
assert(saves == 1)
vim.api.nvim_list_uis, vim.fn.argc = original_uis, original_argc
vim.api.nvim_clear_autocmds({ group = "ConfigResession" })
print("Session checks passed")
