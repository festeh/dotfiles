require("nvim_aider").setup({
  args = {
    "--pretty",
    "--stream",
  },
  auto_reload = true,
  win = {
    wo = { winbar = "Aider" },
    style = "nvim_aider",
    position = "bottom",
  },
})
