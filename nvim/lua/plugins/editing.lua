local config = require("config.lazy").config

return require("config.keymap-check").track_specs({
  { "Pocco81/auto-save.nvim", opts = { trigger_events = "BufLeave" } },
  { "windwp/nvim-autopairs", config = true },
  { "tpope/vim-unimpaired" },
  { "numToStr/Comment.nvim", config = true },
  { "kylechui/nvim-surround", config = true },
  { "echasnovski/mini.nvim", config = config("mini") },
  { "drybalka/tree-climber.nvim", config = config("treeclimber") },
  { url = "https://codeberg.org/andyg/leap.nvim", config = config("leap") },
  { "declancm/cinnamon.nvim", opts = {} },
  {
    "tomasky/bookmarks.nvim",
    opts = { sign_priority = 8 },
  },
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {
      modes = {
        search = {
          enabled = false,
        },
      },
    },
    keys = {
      {
        "Q",
        mode = { "n", "x", "o" },
        function()
          require("flash").treesitter()
        end,
        desc = "Flash Treesitter",
      },
      {
        "r",
        mode = "o",
        function()
          require("flash").remote()
        end,
        desc = "Remote Flash",
      },
      {
        "R",
        mode = { "o", "x" },
        function()
          require("flash").treesitter_search()
        end,
        desc = "Treesitter Search",
      },
      {
        "<c-s>",
        mode = { "c" },
        function()
          require("flash").toggle()
        end,
        desc = "Toggle Flash Search",
      },
    },
  },
  { "lambdalisue/suda.vim" },
  {
    "otavioschwanck/arrow.nvim",
    opts = {
      show_icons = true,
      leader_key = "<c-;>",
    },
  },
  {
    "MagicDuck/grug-far.nvim",
    config = config("grug"),
  },
  {
    "rmagatti/alternate-toggler",
    opts = {},
    keys = {
      {
        "<leader><space>",
        function()
          require("alternate-toggler").toggleAlternate()
        end,
        desc = "Toggle alternate value",
      },
    },
    lazy = false,
  },
})
