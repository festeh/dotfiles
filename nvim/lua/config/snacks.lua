require("snacks").setup(
  {
    picker = { enabled = true },
    gitbrowse = { enabled = true },
    git = { enabled = true },
    lazygit = { enabled = true },
    input = { enabled = true },  -- Better vim.ui.input
  }
)

-- Git keymappings
local snacks = require("snacks")
vim.keymap.set({"n", "x"}, "<leader>gB", function() snacks.gitbrowse() end, { desc = "Git Browse" })
vim.keymap.set({"n", "x"}, "<leader>gO", function() snacks.gitbrowse.open({ what = "repo" }) end, { desc = "Git Browse Repo" })
vim.keymap.set("n", "<leader>gg", function() snacks.lazygit() end, { desc = "Lazygit" })
vim.keymap.set("n", "<leader>l", function() snacks.lazygit() end, { desc = "Lazygit" })
vim.keymap.set("n", "<leader>gF", function() snacks.lazygit.log_file() end, { desc = "Lazygit Current File History" })
vim.keymap.set("n", "<leader>gG", function() snacks.lazygit.log() end, { desc = "Lazygit Log (cwd)" })
vim.keymap.set("n", "<leader>gD", function() snacks.git.blame_line() end, { desc = "Git Blame Line" })

-- Git picker keymappings
vim.keymap.set("n", "<leader>gb", function() snacks.picker.git_branches() end, { desc = "Git Branches" })
vim.keymap.set("n", "<leader>gl", function() snacks.picker.git_log() end, { desc = "Git Log" })
vim.keymap.set("n", "<leader>gL", function() snacks.picker.git_log_line() end, { desc = "Git Log Line" })
vim.keymap.set("n", "<leader>gs", function() snacks.picker.git_status() end, { desc = "Git Status" })
vim.keymap.set("n", "<leader>gS", function() snacks.picker.git_stash() end, { desc = "Git Stash" })
vim.keymap.set("n", "<leader>gd", function() snacks.picker.git_diff() end, { desc = "Git Diff (Hunks)" })
vim.keymap.set("n", "<leader>gf", function() snacks.picker.git_log_file() end, { desc = "Git Log File" })

-- Picker keymappings (replacing Telescope)
local picker = require("snacks").picker
vim.keymap.set('n', '<leader>ff', function() picker.files() end, { desc = 'Find Files' })
vim.keymap.set('n', '<leader>fg', function() picker.grep() end, { desc = 'Live Grep' })
vim.keymap.set('n', '<leader>fw', function() picker.grep_word() end, { desc = 'Grep Word' })
vim.keymap.set('n', '<leader>fb', function() picker.buffers() end, { desc = 'Buffers' })
vim.keymap.set('n', '<leader>fh', function() picker.help() end, { desc = 'Help Tags' })
vim.keymap.set('n', '<leader>fr', function() picker.lsp_references() end, { desc = 'LSP References' })
vim.keymap.set('n', '<leader>fi', function() picker.lsp_incoming_calls() end, { desc = 'LSP Incoming Calls' })
vim.keymap.set('n', '<leader>k', function() picker.lsp_symbols() end, { desc = 'LSP Document Symbols' })
vim.keymap.set('n', '<leader>j', function() picker.recent() end, { desc = 'Recent Files' })
vim.keymap.set('n', '<leader>?', function() picker.recent() end, { desc = 'Recent Files' })
vim.keymap.set('n', '<leader>/', function() picker.lines() end, { desc = 'Search in current buffer' })
vim.keymap.set('n', '<leader>fk', function() picker.keymaps() end, { desc = 'Keymaps' })
