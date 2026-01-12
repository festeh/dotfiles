require("lazy_install")

local function req(mod)
  local full_path = "config." .. mod
  local function lazy_loader()
    require(full_path)
  end

  return lazy_loader
end

local plugins = {
  { 'folke/lazydev.nvim',          config = req("lazydev") },
  { "rafamadriz/friendly-snippets" },
  {
    'saghen/blink.cmp',
    version = '*',
    config = req('blink'),
  },
  { "williamboman/mason.nvim",         config = req("masonlsp") },
  { "nvim-treesitter/nvim-treesitter", config = req('treesitter') },
  { "Pocco81/auto-save.nvim",                      config = req('auto-save') },
  { "windwp/nvim-autopairs",                       config = true },
  { "tpope/vim-unimpaired" },
  { "numToStr/Comment.nvim",                       config = true },
  { "kylechui/nvim-surround",                      config = true },
  { "nvim-lualine/lualine.nvim",                   config = req("lualine") },
  { "akinsho/bufferline.nvim",                     config = req("bufferline") },
  { 'nvim-lua/plenary.nvim' },
  { "kevinhwang91/nvim-bqf",                       config = req("bqf") },
  { 'nvim-treesitter/nvim-treesitter-textobjects', config = req('treesitter-textobjects') },
  { "szw/vim-maximizer" },
  { 'sindrets/diffview.nvim',                      dependencies = { 'nvim-lua/plenary.nvim' } },
  { 'tpope/vim-fugitive' },
  { "lukas-reineke/indent-blankline.nvim",         config = req("indent") },
  { "iamcco/markdown-preview.nvim",                run = function() vim.fn["mkdp#util#install"]() end },
  { 'nvim-neotest/neotest',                        config = req("neotest") },
  { 'nvim-neotest/neotest-python' },
  { 'sbdchd/neoformat',                            config = req("neoformat") },
  { 'DNLHC/glance.nvim',                           config = req('glance') },
  { 'NoahTheDuke/vim-just' },
  {
    'mfussenegger/nvim-dap',
    config = req("dap"),
    dependencies = {
      { "igorlfs/nvim-dap-view", opts = {} },
    },
    event = "VeryLazy"
  },
  { 'mfussenegger/nvim-dap-python',     config = req("dap-python"),        event = "VeryLazy" },
  { "jbyuki/one-small-step-for-vimkind" },
  { 'lakshayg/vim-bazel' },
  { 'echasnovski/mini.nvim',            config = req('mini') },
  { 'drybalka/tree-climber.nvim',       config = req('treeclimber') },
  { 'ziontee113/syntax-tree-surfer',    config = req('syntax_tree_surfer') },
  { 'ggandor/leap.nvim',                config = req("leap") },
  { 'declancm/cinnamon.nvim',           config = req('cinnamon') },
  { 'folke/noice.nvim',                 config = req('noice') },
  { 'folke/trouble.nvim',               config = req('trouble') },
  { "mrjones2014/legendary.nvim",       config = req('legendary') },
  { 'Exafunction/windsurf.vim',         event = "VeryLazy",                config = req('codeium') },
  { 'neomake/neomake' },
  { "windwp/nvim-ts-autotag",           config = req("autotag") },
  {
    'theHamsta/nvim-dap-virtual-text',
    config = req("dap_virtual_text"),
    event = "VeryLazy"
  },
  { 'Civitasv/cmake-tools.nvim', config = req('cmake') },
  {
    "tomasky/bookmarks.nvim",
    config = req("bookmarks"),
  },
  {
    'lewis6991/gitsigns.nvim',
    event = { "VeryLazy" },
    config = req("gitsigns")
  },
  { "axkirillov/hbac.nvim",      config = req("hbac") },
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {
      modes = {
        search = {
          enabled = false,
        }
      }
    },
    keys = {
      { "Q", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
      { "r", mode = "o",               function() require("flash").remote() end,     desc = "Remote Flash" },
      {
        "R",
        mode = { "o", "x" },
        function() require("flash").treesitter_search() end,
        desc = "Treesitter Search"
      },
      {
        "<c-s>",
        mode = { "c" },
        function() require("flash").toggle() end,
        desc = "Toggle Flash Search"
      },
    },
  },
  { "lambdalisue/suda.vim" },
  { "tanvirtin/vgit.nvim" },
  { "L3MON4D3/LuaSnip",    dependencies = { "rafamadriz/friendly-snippets" }, config = req('luasnip') },
  {
    "kevinhwang91/nvim-ufo",
    dependencies = { "kevinhwang91/promise-async" },
    config = req('ufo')
  },
  { "elkowar/yuck.vim" },
  { "luckasRanarison/tree-sitter-hypr" },
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
    "otavioschwanck/arrow.nvim",
    opts = {
      show_icons = true,
      leader_key = '<c-;>',
    }
  },
  { "nvim-neotest/nvim-nio" },
  {
    'stevearc/overseer.nvim',
    config = req('overseer'),
  },
  {
    "stevearc/profile.nvim"
  },
  {
    "pmizio/typescript-tools.nvim",
    dependencies = { "nvim-lua/plenary.nvim", "neovim/nvim-lspconfig" },
    config = req('typescript-tools'),
  },
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    config = req('copilot_chat'),
  },
  {
    "MagicDuck/grug-far.nvim",
    config = req("grug")
  },
  {
    "toppair/peek.nvim",
    event = { "VeryLazy" },
    build = "deno task --quiet build:fast",
    config = function()
      require("peek").setup()
      vim.api.nvim_create_user_command("PeekOpen", require("peek").open, {})
      vim.api.nvim_create_user_command("PeekClose", require("peek").close, {})
    end,
  },
  { "b0o/schemastore.nvim" },
  { 'akinsho/toggleterm.nvim', version = "*", config = true },
  {
    'nvim-flutter/flutter-tools.nvim',
    lazy = false,
    dependencies = {
      'nvim-lua/plenary.nvim',
      'stevearc/dressing.nvim',
    },
    config = req('flutter-tools'),
  },
  {
    'stevearc/resession.nvim',
    config = req('resession'),
  },
  { 'rmagatti/alternate-toggler', config = req('toggler') },
  { 'mrcjkb/rustaceanvim',        config = req('rustacean') },
  { "folke/snacks.nvim",          config = req("snacks") },
  {
    'GeorgesAlkhouri/nvim-aider',
    config = req("aider"),
    event = "VeryLazy",
    dependencies = {
      "folke/snacks.nvim"
    }
  },
  { "catppuccin/nvim",     priority = 1000 },
  { "MunifTanjim/nui.nvim" },
}

local opts = {
  dev = {
    path = "~/projects/",
  }
}

require("lazy").setup(plugins, opts)
