require("nvim-tree").setup()

local function smart_focus()
  if vim.api.nvim_buf_get_option(0, "buftype") ~= "" or vim.api.nvim_buf_get_name(0) == "" then
    vim.cmd("NvimTreeToggle")
  else
    vim.cmd("NvimTreeFindFile")
  end
end

vim.keymap.set({ "n", "x", "i" }, "<A-1>", smart_focus)
vim.keymap.set({ "n", "x", "i" }, "<A-2>", "<cmd>NvimTreeClose<cr>")
