local notify = require("notify")

notify.setup({
  background_colour = "#000000",
  render = "minimal",
  timeout = 1,
  top_down = false,
  -- stages = { function(state)
  --   return nil
  -- end }
})
vim.notify = notify
