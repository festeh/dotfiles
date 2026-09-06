local config = require("config.lazy").config

return require("config.keymap-check").track_specs({
  { "folke/lazydev.nvim", opts = {} },
  {
    "saghen/blink.cmp",
    version = "*",
    config = config("blink"),
  },
  {
    "mason-org/mason.nvim",
    config = function()
      require("mason").setup()
      vim.api.nvim_create_user_command(
        "ToolsInstall",
        require("config.tools").install,
        { desc = "Install missing declared Mason tools" }
      )
    end,
  },
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "mason-org/mason.nvim",
      "saghen/blink.cmp",
      "folke/lazydev.nvim",
      "b0o/schemastore.nvim",
    },
    config = function()
      require("config.lsp").setup()
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = config("treesitter"),
  },
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    branch = "main",
    config = config("treesitter-textobjects"),
  },
  {
    "stevearc/conform.nvim",
    opts = function()
      return {
        formatters_by_ft = require("config.tools").formatters_by_ft(),
        default_format_opts = { lsp_format = "fallback" },
      }
    end,
    cmd = { "ConformInfo" },
    keys = {
      {
        "<leader>m",
        function()
          require("conform").format({ async = true })
        end,
        mode = { "n", "x" },
        desc = "Format buffer or selection",
      },
    },
  },
  { "DNLHC/glance.nvim", config = config("glance") },
  { "NoahTheDuke/vim-just" },
  { "lakshayg/vim-bazel" },
  { "windwp/nvim-ts-autotag", opts = {} },
  { "elkowar/yuck.vim" },
  { "luckasRanarison/tree-sitter-hypr" },
  {
    "pmizio/typescript-tools.nvim",
    dependencies = { "nvim-lua/plenary.nvim", "neovim/nvim-lspconfig" },
    opts = {
      settings = {
        tsserver_file_preferences = {
          includeCompletionsWithSnippetText = false,
          includeCompletionsWithClassMemberSnippets = false,
          includeCompletionsWithObjectLiteralMethodSnippets = false,
        },
      },
    },
  },
  { "b0o/schemastore.nvim" },
  {
    "nvim-flutter/flutter-tools.nvim",
    lazy = false,
    dependencies = {
      "nvim-lua/plenary.nvim",
      "folke/snacks.nvim",
      "neovim/nvim-lspconfig",
    },
    opts = function()
      return {
        dev_log = { enabled = true, notify_errors = true, open_cmd = "tabedit" },
        lsp = { capabilities = require("config.lsp").capabilities() },
        fvm = true,
      }
    end,
  },
  {
    "mrcjkb/rustaceanvim",
    dependencies = { "neovim/nvim-lspconfig" },
    config = config("rustacean"),
  },
  { "Glench/Vim-Jinja2-Syntax" },
})
