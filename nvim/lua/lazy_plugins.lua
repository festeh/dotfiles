require("lazy_install")

local function req(mod)
  local full_path = "config." .. mod
  local function lazy_loader()
    require(full_path)
  end

  return lazy_loader
end

local plugins = {
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
    config = req("lspconfig")
  },
  { "williamboman/mason.nvim",         config = true },
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
  { "nvim-pack/nvim-spectre",                      config = req("spectre") },
  { "kevinhwang91/nvim-bqf",                       config = req("bqf") },
  { 'nvim-treesitter/nvim-treesitter-textobjects', config = req('treesitter-textobjects') },
  { 'stevearc/aerial.nvim',                        config = req('aerial') },
  { "festeh/wilder.nvim",                          config = req("wilder") },
  {
    "j-hui/fidget.nvim",
    tag = "legacy",
    config = req("fidget")
  },
  { 'folke/neodev.nvim' },
  { "szw/vim-maximizer" },
  { 'sindrets/diffview.nvim',              dependencies = { 'nvim-lua/plenary.nvim' } },
  { 'tpope/vim-fugitive' },
  { "lukas-reineke/indent-blankline.nvim", config = req("indent") },
  { "iamcco/markdown-preview.nvim",        run = function() vim.fn["mkdp#util#install"]() end },
  { 'nvim-neotest/neotest',                config = req("neotest") },
  { 'nvim-neotest/neotest-python' },
  { 'sbdchd/neoformat',                    config = req("neoformat") },
  { 'DNLHC/glance.nvim',                   config = req('glance') },
  { 'NoahTheDuke/vim-just' },
  { 'mfussenegger/nvim-dap',               config = req("dap"),                               event = "VeryLazy" },
  { 'rcarriga/nvim-dap-ui',                config = req("dapui"),                             event = "VeryLazy" },
  { "nvim-telescope/telescope-dap.nvim" },
  { "jbyuki/one-small-step-for-vimkind" },
  { 'stevearc/dressing.nvim',              config = req('dressing') },
  -- use
  --   'akinsho/flutter-tools.nvim',
  --   requires = {
  --     'nvim-lua/plenary.nvim',
  --     'stevearc/dressing.nvim', -- optional for vim.ui.select
  --   },
  --   config = [[require('config.flutter-tools')]]
  -- }
  -- use { 'MunifTanjim/exrc.nvim', config = [[require('config.exrc')]] }
  { 'lakshayg/vim-bazel' },
  {
    'ray-x/navigator.lua',
    event = "VeryLazy",
    dependencies = { { 'ray-x/guihua.lua' }, { 'neovim/nvim-lspconfig' } },
    config = req('navigator')
  },
  { 'echasnovski/mini.nvim',           config = req('mini') },
  { 'rcarriga/nvim-notify',            config = req('notify') },
  { 'drybalka/tree-climber.nvim',      config = req('treeclimber') },
  { 'ziontee113/syntax-tree-surfer',   config = req('syntax_tree_surfer') },
  -- { 'themercorp/themer.lua',           config = req('themer') },
  { 'LeonHeidelbach/trailblazer.nvim', config = req('trailblazer') },
  { 'rlane/pounce.nvim',               config = req('pounce') },
  { 'declancm/cinnamon.nvim',          config = req('cinnamon') },
  { "smartpde/telescope-recent-files" },
  { 'ray-x/go.nvim',                   config = req('go') },
  -- {'folke/noice.nvim', config = [[require('config.noice')]] },
  { "mrjones2014/legendary.nvim",      config = req('legendary') },
  -- { 'Exafunction/codeium.vim', event = "VeryLazy", enabled = (vim.g.codeium_enabled == true) },
  { 'neomake/neomake' },
  -- { 'tpope/vim-sleuth' },
  { "windwp/nvim-ts-autotag",          config = req("autotag") },
  {
    'theHamsta/nvim-dap-virtual-text',
    config = req("dap_virtual_text"),
    event = "VeryLazy"
  },
  { 'Civitasv/cmake-tools.nvim', config = req('cmake') },
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "InsertEnter",
    config = req('copilot'),
  },
  {
    'Robitx/gp.nvim', config = req('gp'),
  },
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
  { "lambdalisue/suda.vim" },
  { "tanvirtin/vgit.nvim" },
  { "L3MON4D3/LuaSnip",    dependencies = { "rafamadriz/friendly-snippets" }, config = req('luasnip') },
  {
    "kevinhwang91/nvim-ufo",
    dependencies = { "kevinhwang91/promise-async" },
    config = req('ufo')
  },
  {"catppuccin/nvim", priority=1000},
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
local opts = {}

require("lazy").setup(plugins, opts)
