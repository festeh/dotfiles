local actions = require "telescope.actions"

local telescope = require("telescope")
telescope.load_extension("frecency")

telescope.setup({
  defaults = {
    sorting_strategy = "ascending",
    layout_config = {
      horizontal = {
        width = 0.95,
        preview_width = 0.55
      },
      prompt_position = "top"
    },
    path_display = { "smart", "truncate" },
    mappings = {
      i = {
        ["<Tab>"] = actions.move_selection_next,
        ["<S-Tab>"] = actions.move_selection_previous,
      }
    },
    extensions = {
      frecency = {
        default_workspace = "CWD",
        ignore_patterns = {"*.git/*", "*__pycache__/*"},
        show_unindexed = false,
      }
    }
  }
})

vim.keymap.set('n', '<leader>?', function()
  require('telescope.builtin').oldfiles({ cwd_only = true })
end, { desc = '[?] Find recently opened files' })


vim.keymap.set('n', '<leader>/', function()
  -- You can pass additional configuration to telescope to change theme, layout, etc.
  require('telescope.builtin').current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
    winblend = 10,
    previewer = false,
  })
end, { desc = '[/] Fuzzily search in current buffer]' })
local opts = {}

vim.keymap.set('n', '<leader>ff', "<cmd>lua require('telescope.builtin').find_files()<cr>", opts)
vim.keymap.set('n', '<leader>fg', "<cmd>lua require('telescope.builtin').live_grep()<cr>", opts)
vim.keymap.set('n', '<leader>fb', "<cmd>lua require('telescope.builtin').buffers()<cr>", opts)
vim.keymap.set('n', '<leader>fh', "<cmd>lua require('telescope.builtin').help_tags()<cr>", opts)
vim.keymap.set('n', '<leader>fr', "<cmd>lua require('telescope.builtin').lsp_references()<cr>", opts)
vim.keymap.set('n', '<leader>fi', "<cmd>lua require('telescope.builtin').lsp_incoming_calls()<cr>", opts)
vim.keymap.set('n', '<leader>fd', "<cmd>lua require('telescope.builtin').lsp_definitions()<cr>", opts)
