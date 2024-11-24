require("overseer").setup({
  strategy = {
    "jobstart",
    use_terminal = false,
    -- open_on_start = false,
    -- direction = "float",
    -- size = 30,
    -- quit_on_exit = "always"
  },
  component_aliases = {
    -- Most tasks are initialized with the default components
    default = {
      { "display_duration",      detail_level = 2 },
      "on_output_summarize",
      "on_output_quickfix",
      "on_exit_set_status",
      "on_complete_notify",
      "on_result_diagnostics",
      { "on_result_diagnostics", remove_on_restart = true },
      { "on_complete_dispose",   require_view = { "SUCCESS", "FAILURE" } },
    },
    -- Tasks from tasks.json use these components
    default_vscode = {
      "default",
      -- {"on_result_diagnostics", remove_on_restart = true},
    },
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
