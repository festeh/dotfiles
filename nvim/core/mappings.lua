local keymap = vim.keymap

keymap.set({ "n", "i", "x" }, '<C-s>',
  "<cmd>update<CR><Esc>",
  { silent = true, noremap = true, desc = "save current buffer" })
keymap.set("n", "q:", "<Nop>", { desc = "Doesn't open command history" })
keymap.set("n", "Q", "<Nop>", { desc = "Doesn't open command history" })

keymap.set("n", "x", '"_x', { desc = "delete single character without copying into register" })
keymap.set("n", "<C-k>", "<cmd>Neogit<CR>")

keymap.set("n", "<leader>+", "<C-a>", {desc = {"Increment number"}})
keymap.set("n", "<leader>-", "<C-x>", {desc = {"Decrement number"}})

local M = {}

function M.reload()
  local mod_reload = require("plenary.reload").reload_module
  mod_reload "plugins"
  for key in pairs(package.loaded) do
    if key:find("^config") ~= nil then
      mod_reload(key)
    end
  end
  local cmd = "source " .. vim.fn.stdpath("config") .. "/init.lua"
  vim.cmd(cmd)
  vim.cmd("PackerCompile")
  print("Reloaded all modules")
end

keymap.set("n", '<Leader>r', M.reload)
