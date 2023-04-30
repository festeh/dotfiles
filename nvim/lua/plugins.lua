local fn = vim.fn
local api = vim.api
local packer = require("packer")

local packer_util = require("packer.util")

packer.startup {
  function(use)
    -- use {
    --   'glacambre/firenvim',
    --   run = function() vim.fn['firenvim#install'](0) end
    -- }
    use { "lewis6991/impatient.nvim", config = "require('impatient')" }
    use { "wbthomason/packer.nvim", opt = true }
    use { "nvim-lua/plenary.nvim" }
    use {
      "nvim-tree/nvim-tree.lua",
      requires = { "kyazdani42/nvim-web-devicons" },
      config = [[require('config.nvim-tree')]],
      tag = "nightly"
    }
    use { "hrsh7th/nvim-cmp", config = [[require('config.nvim-cmp')]] }
    use { "rafamadriz/friendly-snippets" }
    use({ "L3MON4D3/LuaSnip", config = "require('config.luasnip')" })

    -- nvim-cmp completion sources
    use { "hrsh7th/cmp-nvim-lsp", after = "nvim-cmp" }
    use { "hrsh7th/cmp-path", after = "nvim-cmp" }
    use { "hrsh7th/cmp-buffer", after = "nvim-cmp" }
    use { "hrsh7th/cmp-omni", after = "nvim-cmp" }
    use { "saadparwaiz1/cmp_luasnip", after = { "nvim-cmp", "LuaSnip" } }

    -- nvim-lsp configuration (it relies on cmp-nvim-lsp, so it should be loaded after cmp-nvim-lsp).
    use { "neovim/nvim-lspconfig", after = "cmp-nvim-lsp", config = [[require('config.lsp')]] }
    use { "williamboman/mason.nvim", config = "require('mason').setup()" }

    use {
      "nvim-treesitter/nvim-treesitter", config = "require('config.treesitter')"
    }
    use { "jubnzv/mdeval.nvim", config = [[require('config.mdeval')]] }
    use { 'ibhagwan/fzf-lua',
      requires = { 'nvim-tree/nvim-web-devicons' },
      config = "require('config.fzf')"
    }
    use { "Pocco81/auto-save.nvim", config = "require('config.auto-save')" }
    use {
      "windwp/nvim-autopairs",
      config = function() require("nvim-autopairs").setup {} end
    }
    use { "tpope/vim-unimpaired" }
    use { "numToStr/Comment.nvim",
      config = function()
        require('Comment').setup()
      end }
    use({
      "kylechui/nvim-surround",
      tag = "*", -- Use for stability; omit to use `main` branch for the latest features
      config = function()
        require("nvim-surround").setup({
          -- Configuration here, or leave empty to use defaults
        })
      end
    })
    use { "nvim-lualine/lualine.nvim", config = "require('config.lualine')" }
    use { "akinsho/bufferline.nvim", config = "require('config.bufferline')" }
    use {
      'nvim-telescope/telescope.nvim', config = [[require('config.telescope')]]
    }
    use { 'lewis6991/gitsigns.nvim', config = "require('config.gitsigns')" }
    use { 'TimUntersberger/neogit', requires = 'nvim-lua/plenary.nvim', config = [[require('config.neogit')]] }
    use { "nvim-pack/nvim-spectre", config = [[require('config.spectre')]] }
    use { "kevinhwang91/nvim-bqf", config = [[require('config.bqf')]] }
    use { 'nvim-treesitter/nvim-treesitter-textobjects', config = [[require('config.treesitter-textobjects')]] }
    use { 'stevearc/aerial.nvim', config = [[require('config.aerial')]] }
    use { "gelguy/wilder.nvim", config = [[require('config.wilder')]] }
    use { "j-hui/fidget.nvim", config = [[require('config.fidget')]] }

    use { "tpope/vim-sleuth" }
    use { 'folke/neodev.nvim' }
    use { "AckslD/nvim-FeMaco.lua", config = [[require("config.femaco")]] }
    use { "szw/vim-maximizer" }
    -- use {
    --   'Exafunction/codeium.vim',
    --   config = function()
    --     vim.keymap.set('i', '<C-g>', function()
    --       return vim.fn['codeium#Accept']()
    --     end, { expr = true })
    --   end
    -- }
    use { 'sindrets/diffview.nvim', requires = 'nvim-lua/plenary.nvim' }
    use { 'tpope/vim-fugitive' }
    use { 'nvim-neotest/neotest-python' }
    use { "lukas-reineke/indent-blankline.nvim", config = [[require("config.indent")]] }
    use { "iamcco/markdown-preview.nvim", run = function() vim.fn["mkdp#util#install"]() end }
    use { 'nvim-neotest/neotest', config = [[require("config.neotest")]] }
    use { 'sbdchd/neoformat', config = [[require('config.neoformat')]] }
    use { 'DNLHC/glance.nvim', config = [[require('config.glance')]] }
    use { 'NoahTheDuke/vim-just' }
    use {
      'chipsenkbeil/distant.nvim',
      config = function()
        require('distant').setup {
          ['*'] = require('distant.settings').chip_default()
        }
      end
    }
    use { 'mfussenegger/nvim-dap', config = [[require('config.dap')]] }
    use { 'rcarriga/nvim-dap-ui', config = [[require('config.dapui')]] }
    use { 'simrat39/rust-tools.nvim', after = { "nvim-lspconfig", "cmp-nvim-lsp" },
      config = [[require('config.rusttools')]] }
    use { 'stevearc/dressing.nvim', config = [[require('config.dressing')]] }
    use {
      'akinsho/flutter-tools.nvim',
      requires = {
        'nvim-lua/plenary.nvim',
        'stevearc/dressing.nvim', -- optional for vim.ui.select
      },
      config = [[require('config.flutter-tools')]]
    }
    use { 'MunifTanjim/exrc.nvim', config = [[require('config.exrc')]] }
    use { 'lakshayg/vim-bazel' }
    use({
      'ray-x/navigator.lua',
      requires = {
        { 'ray-x/guihua.lua',     run = 'cd lua/fzy && make' },
        { 'neovim/nvim-lspconfig' },
      },
      config = [[require('config.navigator')]]
    })
    use { 'echasnovski/mini.nvim', config = [[require('config.mini')]] }
    use { 'rcarriga/nvim-notify', config = [[require('config.notify')]] }
    use { 'drybalka/tree-climber.nvim', config = [[require('config.treeclimber')]] }
    use { 'themercorp/themer.lua', config = [[require('config.themer')]] }
    use {
      "glacambre/firenvim",
      run = function()
        vim.fn["firenvim#install"](0)
      end,
    }
    use {'LeonHeidelbach/trailblazer.nvim', config = [[require('config.trailblazer')]]}
    use {'rlane/pounce.nvim', config = [[require('config.pounce')]] }
    use {
      'declancm/cinnamon.nvim',
      config = function() require('cinnamon').setup() end
    }
    use {"smartpde/telescope-recent-files"}

    -- %Next goes here
    --
    -- use { "MunifTanjim/nui.nvim" }
    -- use({
    --   "jackMort/ChatGPT.nvim",
    --   config = function()
    --     require("chatgpt").setup({
    --       max_tokens=10000
    --     })
    --   end,
    --   requires = {
    --     "MunifTanjim/nui.nvim",
    --     "nvim-lua/plenary.nvim",
    --     "nvim-telescope/telescope.nvim"
    --   }
    -- })

    use { "navarasu/onedark.nvim", opt = true }
    use { "sainnhe/edge", opt = true }
    use { "sainnhe/sonokai", opt = true }
    use { "sainnhe/gruvbox-material", opt = true }
    use { "shaunsingh/nord.nvim", opt = true }
    use { "sainnhe/everforest", opt = true }
    use { "EdenEast/nightfox.nvim", opt = true }
    use { "rebelot/kanagawa.nvim", opt = true }
    use { "catppuccin/nvim", as = "catppuccin", opt = true }
    use { "rose-pine/neovim", as = 'rose-pine', opt = true }
    use { "olimorris/onedarkpro.nvim", opt = true }
    use { "tanvirtin/monokai.nvim", opt = true }
    use { "marko-cerovac/material.nvim", opt = true }
    use { "kyazdani42/nvim-web-devicons", event = "VimEnter" }
    -- use { "olimorris/persisted.nvim", config = [[require('config.persisted')]] }
  end,
  config = {
    max_jobs = 7,
    compile_path = packer_util.join_paths(fn.stdpath("data"), "site", "lua", "packer_compiled.lua")
  }
}

local status, _ = pcall(require, "packer_compiled")
if not status then
  local msg = "File packer_compiled.lua not found: run PackerSync to fix!"
  vim.notify(msg, vim.log.levels.ERROR, { title = "nvim-config" })
end


-- Auto-generate packer_compiled.lua file
api.nvim_create_autocmd({ "BufWritePost" }, {
  pattern = "*/nvim/lua/plugins.lua",
  group = api.nvim_create_augroup("packer_auto_compile", { clear = true }),
  callback = function(ctx)
    local cmd = "source " .. ctx.file
    vim.cmd(cmd)
    vim.cmd("PackerCompile")
    vim.notify("PackerCompile done!", vim.log.levels.INFO, { title = "Nvim-config" })
  end,
})
