require 'navigator'.setup({
  debug = false,                                       -- log output, set to true and log path: ~/.cache/nvim/gh.log
  width = 0.75,                                        -- max width ratio (number of cols for the floating window) / (window width)
  height = 0.3,                                        -- max list window height, 0.3 by default
  preview_height = 0.35,                               -- max height of preview windows
  border = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" }, -- border style, can be one of 'none', 'single', 'double',
  -- 'shadow', or a list of chars which defines the border
  on_attach = function(client, bufnr)
    -- your hook
  end,
  -- put a on_attach of your own here, e.g
  -- function(client, bufnr)
  --   -- the on_attach will be called at end of navigator on_attach
  -- end,
  -- The attach code will apply to all LSP clients

  ts_fold = {
    enable = false,
  },                                                                -- modified version of treesitter folding
  default_mapping = true,                                                         -- set to false if you will remap every key or if you using old version of nvim-
  keymaps = { { key = "gK", func = vim.lsp.declaration, desc = 'declaration' } }, -- a list of key maps
  -- this kepmap gK will override "gD" mapping function declaration()  in default kepmap
  -- please check mapping.lua for all keymaps
  treesitter_analysis = true,          -- treesitter variable context
  treesitter_navigation = true,        -- bool|table false: use lsp to navigate between symbol ']r/[r', table: a list of
  --lang using TS navigation
  treesitter_analysis_max_num = 100,   -- how many items to run treesitter analysis
  treesitter_analysis_condense = true, -- condense form for treesitter analysis
  -- this value prevent slow in large projects, e.g. found 100000 reference in a project
  transparency = 50,                   -- 0 ~ 100 blur the main window, 100: fully transparent, 0: opaque,  set to nil or 100 to disable it
  lsp_signature_help = true,           -- if you would like to hook ray-x/lsp_signature plugin in navigator
  -- setup here. if it is nil, navigator will not init signature help
  signature_help_cfg = nil,            -- if you would like to init ray-x/lsp_signature plugin in navigator, and pass in your own config to signature help
  icons = {
    -- Code action
    code_action_icon = "🏏", -- note: need terminal support, for those not support unicode, might crash
    -- Diagnostics
    diagnostic_head = '🐛',
    diagnostic_head_severity_1 = "🈲",
    -- refer to lua/navigator.lua for more icons setups
  },
  mason = false,          -- set to true if you would like use the lsp installed by williamboman/mason
  lsp = {
    disable_lsp = "all", -- skip lsp setup, and only use treesitter in navigator.
    -- Use this if you are not using LSP servers, and only want to enable treesitter support.
    -- If you only want to prevent navigator from touching your LSP server configs,
    -- use `disable_lsp = "all"` instead.
    -- If disabled, make sure add require('navigator.lspclient.mapping').setup({bufnr=bufnr, client=client}) in your
    -- own on_attach

    -- hover = {
    --   enable = false,
    --   keymap = {
    --     ['<C-k>'] = {
    --       go = function()
    --         local w = vim.fn.expand('<cWORD>')
    --         vim.cmd('GoDoc ' .. w)
    --       end,
    --       default = function(
    --         local w = vim.fn.expand('<cWORD>')
    --         vim.lsp.buf.workspace_symbol(w)
    --       end,
    --     },
    --   },

    diagnostic_scrollbar_sign = { '▃', '▆', '█' }, -- experimental:  diagnostic status in scroll bar area; set to false to disable the diagnostic sign,
    --                for other style, set to {'╍', 'ﮆ'} or {'-', '='}
    diagnostic_virtual_text = true,                -- show virtual for diagnostic message
    diagnostic_update_in_insert = false,           -- update diagnostic message in insert mode
    disply_diagnostic_qf = false,                  -- always show quickfix if there are diagnostic errors, set to false if you want to ignore it
    tsserver = {
      filetypes = { 'typescript' }                 -- disable javascript etc,
      -- set to {} to disable the lspclient for all filetypes
    },
    ctags = {
      cmd = 'ctags',
      tagfile = 'tags',
      options = '-R --exclude=.git --exclude=node_modules --exclude=test --exclude=vendor --excmd=number',
    },
    -- lua_ls = {
    --   sumneko_root_path = vim.fn.expand("$HOME") .. "/github/sumneko/lua-language-server",
    --   sumneko_binary = vim.fn.expand("$HOME") .. "/github/sumneko/lua-language-server/bin/macOS/lua-language-server",
    -- },
    servers = {}, -- by default empty, and it should load all LSP clients avalible based on filetype
    -- but if you whant navigator load  e.g. `cmake` and `ltex` for you , you
    -- can put them in the `servers` list and navigator will auto load them.
    -- you could still specify the custom config  like this
    -- cmake = {filetypes = {'cmake', 'makefile'}, single_file_support = false},
  }
})
