require("overseer").setup({
  strategy = {
    "toggleterm",
    open_on_start = false,
    direction = "float",
    size = 30,
    quit_on_exit = "always"
  },
  -- log = {
  --   {
  --     type = "echo",
  --     level = vim.log.levels.TRACE,
  --   },
  --   {
  --     type = "file",
  --     filename = "overseer.log",
  --     level = vim.log.levels.TRACE,
  --   },
  -- },
})
