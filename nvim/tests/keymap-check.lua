-- Run from the config directory: nvim --headless -u NONE -i NONE -l tests/keymap-check.lua
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.rtp:prepend(root)
vim.g.mapleader = " "
local checker = require("config.keymap-check")
checker.setup()

local function find(kind, lhs, mode)
  local key = vim.api.nvim_replace_termcodes(lhs, true, true, true)
  for _, conflict in ipairs(checker.collect()) do
    if conflict.kind == kind and conflict.lhs == key and conflict.mode == (mode or "n") then
      return conflict
    end
  end
end

-- Leader expansion, overwritten actions, and removal of stale reports.
vim.keymap.set("n", "<leader>Z1", "aa", { desc = "First action" })
vim.keymap.set("n", " Z1", "bb", { desc = "Second action" })
assert(find("overwrite", " Z1").message:find("First action", 1, true))
vim.keymap.del("n", " Z1")
assert(not find("overwrite", " Z1"))

-- Case-insensitive notation and overlapping visual modes normalize correctly.
vim.keymap.set("x", "<C-F12>", "aa")
vim.keymap.set("v", "<c-f12>", "bb")
assert(find("overwrite", "<C-F12>", "x"))
assert(not find("overwrite", "<C-F12>", "s"))

-- A prefix action causes a wait; a mode separation does not.
vim.keymap.set("n", " Z2", "aa")
vim.keymap.set("n", " Z2r", "bb")
assert(find("prefix", " Z2").other_lhs == " Z2r")
vim.keymap.set("n", " Z3", "aa")
vim.keymap.set("x", " Z3r", "bb")
assert(not find("prefix", " Z3"))

-- Reservations, expression operators, and repeated identical mappings are benign.
vim.keymap.set("n", " Z4", "<Nop>")
vim.keymap.set("n", " Z4r", "bb")
assert(not find("prefix", " Z4"))
vim.keymap.set("n", " Z5", function()
  return "g@"
end, { expr = true })
vim.keymap.set("n", " Z5r", "bb")
assert(not find("prefix", " Z5"))
vim.keymap.set("n", " Z6", "aa")
vim.keymap.set("n", " Z6", "aa")
assert(not find("overwrite", " Z6"))

-- Local overrides are legitimate, but local/global prefix collisions still matter.
vim.keymap.set("n", " Z7", "aa")
vim.keymap.set("n", " Z7", "bb", { buffer = true })
assert(not find("overwrite", " Z7"))
vim.keymap.set("n", " Z7r", "cc")
assert(find("prefix", " Z7"))

-- Lazy key declarations stay visible through its placeholder replacement.
checker.track_specs({
  { "test/one", keys = { { " Z8", "aa" }, { " Z8r", "bb" } } },
  { "test/two", keys = { { " Z8", "cc" } } },
})
local plugin = assert(loadstring(
  [[
  vim.keymap.set('n', ' Z8', function() end, { expr = true })
  vim.keymap.set('n', ' Z8r', 'bb')
]],
  "@/plugin/lazy/keys.lua"
))
plugin()
assert(find("prefix", " Z8"), "Lazy placeholders must not hide prefix conflicts")
plugin = assert(loadstring(
  [[
  vim.keymap.del('n', ' Z8')
  vim.keymap.set('n', ' Z8', 'cc')
  vim.keymap.set('n', ' Z8r', 'bb')
]],
  "@/plugin/lazy/keys.lua"
))
plugin()
assert(find("overwrite", " Z8"))
assert(find("prefix", " Z8"))

-- Another buffer's local mappings cannot produce a false positive here.
local current = vim.api.nvim_get_current_buf()
local other = vim.api.nvim_create_buf(true, false)
vim.keymap.set("n", " Z9", "aa", { buffer = current })
vim.keymap.set("n", " Z9r", "bb", { buffer = other })
assert(not find("prefix", " Z9"))
vim.api.nvim_buf_delete(other, { force = true })

checker.show()
assert(vim.bo.buftype == "nofile" and not vim.bo.modifiable)
assert(
  table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n"):find("First action", 1, true)
    == nil
)
print("Keymap checks passed")
