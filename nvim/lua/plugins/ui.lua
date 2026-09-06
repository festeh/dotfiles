local config = require("config.lazy").config

return require("config.keymap-check").track_specs({
  { "nvim-lualine/lualine.nvim", config = config("lualine") },
  { "akinsho/bufferline.nvim", config = config("bufferline") },
  { "kevinhwang91/nvim-bqf", config = config("bqf") },
  { "szw/vim-maximizer" },
  {
    "folke/noice.nvim",
    dependencies = { "MunifTanjim/nui.nvim" },
    config = config("noice"),
  },
  { "folke/trouble.nvim", opts = { auto_preview = false } },
  { "axkirillov/hbac.nvim", config = config("hbac") },
  {
    "kevinhwang91/nvim-ufo",
    dependencies = { "kevinhwang91/promise-async" },
    config = config("ufo"),
  },
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown" },
    opts = {},
    keys = {
      {
        "<leader>tm",
        function()
          require("render-markdown").toggle()
        end,
        desc = "Toggle Markdown Render",
      },
    },
  },
  { "akinsho/toggleterm.nvim", version = "*", config = true },
  {
    "stevearc/resession.nvim",
    config = config("resession"),
  },
  { "folke/snacks.nvim", lazy = false, priority = 1000, config = config("snacks") },
  { "catppuccin/nvim", priority = 1000 },
})
