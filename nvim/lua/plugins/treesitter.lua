local treesitter = require 'nvim-treesitter.configs'

treesitter.setup {
    ensure_installed = { "go", "lua", "rust", "python", "bash" },
    sync_install = false,
    auto_install = false,
    ignore_install = {},
    highlight = {
        enable = true,
        disable = {},
        additional_vim_regex_highlighting = false,
    },
    incremental_selection = {
        enable = true,
        keymaps = {
            init_selection = "<c-w>",
            node_incremental = "<c-w>",
            scope_incremental = "grc",
            node_decremental = "<c-s-w>",
        },
    }
}
