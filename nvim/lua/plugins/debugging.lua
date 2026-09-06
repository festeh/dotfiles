local config = require("config.lazy").config

return require("config.keymap-check").track_specs({
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/neotest-python",
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    config = config("neotest"),
  },
  {
    "mfussenegger/nvim-dap",
    config = config("dap"),
    dependencies = {
      { "igorlfs/nvim-dap-view", opts = {} },
      "mason-org/mason.nvim",
    },
    event = "VeryLazy",
  },
  {
    "mfussenegger/nvim-dap-python",
    dependencies = { "mfussenegger/nvim-dap" },
    config = function()
      require("dap-python").setup("uv", { console = "internalConsole", justMyCode = false })
    end,
    event = "VeryLazy",
  },
  { "jbyuki/one-small-step-for-vimkind" },
  {
    "theHamsta/nvim-dap-virtual-text",
    dependencies = { "mfussenegger/nvim-dap" },
    opts = {},
    event = "VeryLazy",
  },
  {
    "Civitasv/cmake-tools.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {
      cmake_command = "cmake",
      cmake_regenerate_on_save = false,
      cmake_notifications = { enabled = false },
    },
  },
  {
    "benlubas/molten-nvim",
    build = ":UpdateRemotePlugins",
    init = function()
      vim.g.molten_auto_open_output = false
      vim.g.molten_enter_output_behavior = "open_and_enter"
      vim.g.molten_output_virt_lines = true
      vim.g.molten_output_win_max_height = 50
      vim.g.molten_virt_text_output = true
      vim.g.molten_virt_text_max_lines = 12
    end,
  },
  {
    "stevearc/overseer.nvim",
    config = config("overseer"),
  },
  {
    "stevearc/profile.nvim",
  },
})
