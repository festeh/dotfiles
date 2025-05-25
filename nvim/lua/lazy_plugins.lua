require("lazy_install")

local function req(mod)
  local full_path = "config." .. mod
  local function lazy_loader()
    require(full_path)
  end

  return lazy_loader
end

local plugins = {
  { 'folke/neodev.nvim',           config = req("neodev") },
  {
    "nvim-tree/nvim-tree.lua",
    version = "*",
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    config = req("nvim-tree")
  },
  { "hrsh7th/nvim-cmp",            config = req("nvim-cmp") },
  { "rafamadriz/friendly-snippets" },
  -- nvim-cmp completion sources
  { "hrsh7th/cmp-nvim-lsp",        dependencies = { "nvim-cmp" } },
  { "hrsh7th/cmp-path",            dependencies = { "nvim-cmp" } },
  { "hrsh7th/cmp-buffer",          dependencies = { "nvim-cmp" } },
  { "hrsh7th/cmp-omni",            dependencies = { "nvim-cmp" } },
  { "saadparwaiz1/cmp_luasnip",    dependencies = { "nvim-cmp", "LuaSnip" } },
  {
    "neovim/nvim-lspconfig",
    dependencies = { "cmp-nvim-lsp" },
  },
  { "williamboman/mason.nvim",         config = req("masonlsp") },
  { "nvim-treesitter/nvim-treesitter", config = req('treesitter') },
  {
    'ibhagwan/fzf-lua',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = req("fzf")
  },
  { "Pocco81/auto-save.nvim",                      config = req('auto-save') },
  { "windwp/nvim-autopairs",                       config = true },
  { "tpope/vim-unimpaired" },
  { "numToStr/Comment.nvim",                       config = true },
  { "kylechui/nvim-surround",                      config = true },
  { "nvim-lualine/lualine.nvim",                   config = req("lualine") },
  { "akinsho/bufferline.nvim",                     config = req("bufferline") },
  { 'nvim-telescope/telescope.nvim',               config = req("telescope") },
  { 'nvim-lua/plenary.nvim' },
  { "kevinhwang91/nvim-bqf",                       config = req("bqf") },
  { 'nvim-treesitter/nvim-treesitter-textobjects', config = req('treesitter-textobjects') },
  -- { 'stevearc/aerial.nvim',                        config = req('aerial') },
  { "festeh/wilder.nvim",                          config = req("wilder") },
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
      -- { "festeh/nvim-dap-view", opts = {}, dev = true },
      { "igorlfs/nvim-dap-view", opts = {} },
    },
    event = "VeryLazy"
  },
  { 'mfussenegger/nvim-dap-python',     config = req("dap-python"),          event = "VeryLazy" },
  { "nvim-telescope/telescope-dap.nvim" },
  { "jbyuki/one-small-step-for-vimkind" },
  { 'stevearc/dressing.nvim',           config = req('dressing') },
  -- use { 'MunifTanjim/exrc.nvim', config = [[require('config.exrc')]] }
  { 'lakshayg/vim-bazel' },
  { 'echasnovski/mini.nvim',            config = req('mini') },
  { 'drybalka/tree-climber.nvim',       config = req('treeclimber') },
  { 'ziontee113/syntax-tree-surfer',    config = req('syntax_tree_surfer') },
  -- { 'themercorp/themer.lua',           config = req('themer') },
  -- { 'LeonHeidelbach/trailblazer.nvim', config = req('trailblazer') },
  { 'ggandor/leap.nvim',                config = req("leap") },
  { 'declancm/cinnamon.nvim',           config = req('cinnamon') },
  { "smartpde/telescope-recent-files" },
  -- { 'ray-x/go.nvim',                   config = req('go') },
  { 'folke/noice.nvim',                 config = [[require('config.noice')]] },
  { "mrjones2014/legendary.nvim",       config = req('legendary') },
  { 'Exafunction/windsurf.vim',         event = "VeryLazy",                  config = req('codeium') },
  { 'neomake/neomake' },
  { "windwp/nvim-ts-autotag",           config = req("autotag") },
  {
    'theHamsta/nvim-dap-virtual-text',
    config = req("dap_virtual_text"),
    event = "VeryLazy"
  },
  { 'Civitasv/cmake-tools.nvim', config = req('cmake') },
  -- {
  --   "zbirenbaum/copilot.lua",
  --   cmd = "Copilot",
  --   event = "InsertEnter",
  --   config = req('copilot'),
  -- },
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
    "kdheepak/lazygit.nvim",
    init = function()
      req('lazygit-vim')
    end,
  },
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
    -- stylua: ignore
    keys = {
      -- { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash" },
      { "Q", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
      { "r", mode = "o",               function() require("flash").remote() end,     desc = "Remote Flash" },
      {
        "R",
        mode = { "o", "x" },
        function() require("flash").treesitter_search() end,
        desc =
        "Treesitter Search"
      },
      {
        "<c-s>",
        mode = { "c" },
        function() require("flash").toggle() end,
        desc =
        "Toggle Flash Search"
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
  -- { "theRealCarneiro/hyprland-vim-syntax", event = "VeryLazy" },
  { "luckasRanarison/tree-sitter-hypr" },
  { "williamboman/mason-lspconfig.nvim" },
  -- {
  --   'OscarCreator/rsync.nvim',
  --   build = 'make',
  --   dependencies = 'nvim-lua/plenary.nvim',
  --   config = function()
  --     require("rsync").setup({})
  --   end,
  -- },
  {
    "benlubas/molten-nvim",
    build = ":UpdateRemotePlugins",
    init = function()
      -- this is an example, not a default. Please see the readme for more configuration options
      vim.g.molten_auto_open_output = false
      vim.g.molten_enter_output_behavior = "open_and_enter"
      -- vim.g.molten_output_show_more = true
      vim.g.molten_output_virt_lines = true
      vim.g.molten_output_win_max_height = 50
      -- vim.g.molten_use_border_highlights = true
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
  -- {
  --   'festeh/todoist.lua',
  --   dependencies = {
  --     'nvim-lua/plenary.nvim',
  --     'muniftanjim/nui.nvim',
  --   },
  --   dev = true,
  -- },
  -- {
  --   'festeh/dllm.nvim',
  --   dev = true,
  --   config = true,
  -- },
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
    -- dev = true,
  },
  {
    "MagicDuck/grug-far.nvim",
    config = function() require("grug-far").setup() end
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
      'stevearc/dressing.nvim', -- optional for vim.ui.select
    },
    config = req('flutter-tools'),
  },
  {
    'stevearc/resession.nvim',
    config = req('resession'),
  },

  -- % themes
  { "catppuccin/nvim",     priority = 1000 },
  -- {
  --   'festeh/llm_flow.nvim',
  --   dev = true,
  -- },

  -- -- %Next goes here
  -- --
  { "MunifTanjim/nui.nvim" },
  -- -- use({
  -- --   "jackMort/ChatGPT.nvim",
  -- --   config = function()
  -- --     require("chatgpt").setup({
  -- --       max_tokens=10000
  -- --     })
  -- --   end,
  -- --   requires = {
  -- --     "MunifTanjim/nui.nvim",
  -- --     "nvim-lua/plenary.nvim",
  -- --     "nvim-telescope/telescope.nvim"
  -- --   }
  -- -- })
  --
}
local opts = {
  dev = {
    path = "~/projects/",
  }
}

require("lazy").setup(plugins, opts)
