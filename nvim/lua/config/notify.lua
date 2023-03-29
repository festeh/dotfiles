local notify = require("notify")

notify.setup({
  render = "minimal",
  timeout = 10,
  top_down = false,
})
vim.notify = notify
