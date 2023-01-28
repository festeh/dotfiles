local keymap = vim.keymap

keymap.set({ "n", "i", "x" }, '<C-s>',
  "<cmd>update<CR><Esc>",
  { silent = true, noremap = true, desc = "save current buffer" })
keymap.set("n", "q:", "<Nop>", { desc = "Doesn't open command history" })
keymap.set("n", "Q", "<Nop>", { desc = "Doesn't open command history" })

keymap.set("n", "x", '"_x', { desc = "delete single character without copying into register" })
keymap.set("n", "<C-k>", "<cmd>Neogit<CR>")

keymap.set("n", "<leader>+", "<C-a>", { desc = { "Increment number" } })
keymap.set("n", "<leader>-", "<C-x>", { desc = { "Decrement number" } })

keymap.set("x", "<", "<gv", { desc = "Shift selection left" })
keymap.set("x", ">", ">gv", { desc = "Shift selelction right" })


keymap.set("n", "<leader>q", "<cmd>q<CR>", { desc = "Close window" })

keymap.set("n", "<F11>", "<cmd>set spell!<cr>", { desc = "toggle spell" })
keymap.set("i", "<F11>", "<c-o><cmd>set spell!<cr>", { desc = "toggle spell" })

-- Switch windows
keymap.set("n", "<left>", "<c-w>h")
keymap.set("n", "<Right>", "<C-W>l")
keymap.set("n", "<Up>", "<C-W>k")
keymap.set("n", "<Down>", "<C-W>j")
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
