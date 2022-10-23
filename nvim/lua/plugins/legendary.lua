require('legendary').setup({
    -- Include builtins by default, set to false to disable
    include_builtin = true,
    -- Include the commands that legendary.nvim creates itself
    -- in the legend by default, set to false to disable
    include_legendary_cmds = true,
    -- Customize the prompt that appears on your vim.ui.select() handler
    -- Can be a string or a function that takes the `kind` and returns
    -- a string. See "Item Kinds" below for details. By default,
    -- prompt is 'Legendary' when searching all items,
    -- 'Legendary Keymaps' when searching keymaps,
    -- 'Legendary Commands' when searching commands,
    -- and 'Legendary Autocmds' when searching autocmds.
    -- select_prompt = nil,
    -- Optionally pass a custom formatter function. This function
    -- receives the item as a parameter and must return a table of
    -- non-nil string values for display. It must return the same
    -- number of values for each item to work correctly.
    -- The values will be used as column values when formatted.
    -- See function `get_default_format_values(item)` in
    -- `lua/legendary/formatter.lua` to see default implementation.
    -- formatter = nil,
    -- When you trigger an item via legendary.nvim,
    -- show it at the top next time you use legendary.nvim
    most_recent_item_at_top = true,
    -- Initial keymaps to bind
    keymaps = {
        -- LSP Generics
        { '<leader>fm', vim.lsp.buf.format, description = 'Format buffer with LSP' },
        { '<leader>lr', vim.lsp.buf.rename, description = 'Rename variable with LSP' },
        { '<leader>la', vim.lsp.buf.code_action, description = 'Code action with LSP' },
        { '<leader>ld', vim.diagnostic.open_float, description = 'Line diagnostics with LSP' },
        { '<leader>l]', vim.diagnostic.goto_next, description = 'Jump next diagnostics with LSP' },
        { '<leader>l[', vim.diagnostic.goto_prev, description = 'Jump prev diagnostics with LSP' },
        { '<leader>lk', vim.lsp.buf.hover, description = 'Show help with LSP' },
        --        TODO: this is not supported for some LSP
        { '<leader>li', vim.lsp.buf.implementation, description = 'Show symbol implemetations with LSP' },
        { '<leader>lp', vim.lsp.buf.signature_help, description = 'Show method signature with LSP' },
        { '<leader>lwl', "<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>", description = 'Show workspace list for LSP' },
        { 'gd', vim.lsp.buf.definition, description = "Definition" },
        { 'gD', vim.lsp.buf.declaration, description = "Declaration" },
        { 'gs', vim.lsp.buf.signature_help, description = "Signature Help" },
        { 'gi', vim.lsp.buf.implementation, description = "Goto Implementation" },
        { 'gt', vim.lsp.buf.type_definition, description = "Goto Type Definition" },
        -- Telescope
        { '<leader>td', ":Telescope diagnostics<CR>", description = 'Line diagnostics with Telescope' },
        { '<leader>tg', ":Telescope live_grep<CR>", description = 'Grep with rg and Telescope' },
        { '<leader>tc', ":Telescope commands<CR>", description = 'Search command with Telescope' },
        { '<leader>tr', ":Telescope lsp_references<CR>", description = 'List of references for symbol with Telescope' },
        { '<leader>ts', ":Telescope lsp_document_symbols<CR>", description = 'List document symbols with Telelscope' },
        { '<leader>tw', ":Telescope lsp_workspace_symbols<CR>", description = 'List workspace symbols with Telelscope' },
        { '<C-f>', ":Telescope current_buffer_fuzzy_find<CR>", description = 'List workspace symbols with Telelscope' },
        -- Tests
        { '<leader>t', ":TestNearest<CR>", description = "Test nearest"},
        { '<leader>T', ":TestFile<CR>", description = "Test file"},
    },
    -- Initial commands to bind
    commands = {
        -- your command tables here
    },
    -- Initial augroups and autocmds to bind
    autocmds = {
        -- your autocmd tables here
    },
    -- which_key = {
    --   -- you can put which-key.nvim tables here,
    --   -- or alternatively have them auto-register,
    --   -- see section on which-key integration
    --   mappings = {},
    --   opts = {},
    --   -- controls whether legendary.nvim actually binds they keymaps,
    --   -- or if you want to let which-key.nvim handle the bindings.
    --   -- if not passed, true by default
    --   do_binding = {},
    -- },
    -- Automatically add which-key tables to legendary
    -- see "which-key.nvim Integration" below for more details
    auto_register_which_key = true,
    -- settings for the :LegendaryScratch command
    scratchpad = {
        -- configure how to show results of evaluated Lua code,
        -- either 'print' or 'float'
        -- Pressing q or <ESC> will close the float
        display_results = 'float',
    },
})
