local config = require("config.lazy").config

return require("config.keymap-check").track_specs({
  { "sindrets/diffview.nvim", dependencies = { "nvim-lua/plenary.nvim" } },
  { "tpope/vim-fugitive" },
  {
    "lewis6991/gitsigns.nvim",
    event = { "VeryLazy" },
    config = config("gitsigns"),
  },
})
