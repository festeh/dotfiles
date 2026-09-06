local config = require("config.lazy").config

return require("config.keymap-check").track_specs({
  {
    "Exafunction/windsurf.vim",
    event = "VeryLazy",
    config = config("codeium"),
  },
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = config("copilot_chat"),
  },
  {
    "GeorgesAlkhouri/nvim-aider",
    config = config("aider"),
    event = "VeryLazy",
    dependencies = {
      "folke/snacks.nvim",
    },
  },
})
