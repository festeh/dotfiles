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
vim.keymap.set({"n", "x"}, "<leader>gO", function() snacks.gitbrowse.open() end, { desc = "Git Browse Repo" })
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

-- vim-fugitive unified diff keymappings
vim.keymap.set("n", "<leader>gM", function()
  vim.cmd('tabnew')
  vim.cmd('Git ++curwin diff origin/master')
end, { desc = "Git Diff origin/master (unified inline)" })

-- Custom picker to show files changed vs master with stats
local function git_diff_files_master()
  snacks.picker.pick({
    finder = function(_, ctx)
      return require("snacks.picker.source.proc").proc({
        cmd = "git",
        args = { "diff", "--numstat", "origin/master...HEAD" },
        transform = function(item)
          -- Parse numstat format: "added\tdeleted\tfilename"
          local added, deleted, file = item.text:match("^(%S+)%s+(%S+)%s+(.+)$")
          if file then
            item.file = file
            item.added = added
            item.deleted = deleted
          end
        end,
      }, ctx)
    end,
    format = function(item, opts)
      local ret = {} ---@type string[]
      local file_part = item.file or item.text
      local stats = ""
      if item.added and item.deleted then
        stats = string.format("  +%s -%s", item.added, item.deleted)
      end
      table.insert(ret, { file_part, "Normal" })
      if stats ~= "" then
        table.insert(ret, { stats, "Comment" })
      end
      return ret
    end,
    confirm = function(picker, item)
      -- Close picker
      picker:close()

      -- Find the tab with fugitive diff buffer and switch to it
      local found = false
      for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
          local buf = vim.api.nvim_win_get_buf(win)
          local bufname = vim.api.nvim_buf_get_name(buf)
          -- Check if this is a fugitive git buffer
          if bufname:match("^fugitive://") or vim.bo[buf].filetype == "git" then
            vim.api.nvim_set_current_tabpage(tab)
            vim.api.nvim_set_current_win(win)
            found = true
            break
          end
        end
        if found then break end
      end

      -- If not found, open the diff in a new tab
      if not found then
        vim.cmd('tabnew')
        vim.cmd('Git ++curwin diff origin/master')
      end

      -- Search for the file in the diff buffer
      local search_pattern = "diff --git.*" .. item.file
      vim.fn.search(search_pattern)
    end,
    title = "Git Diff Files (origin/master)",
  })
end

vim.keymap.set("n", "<leader>gF", git_diff_files_master, { desc = "Picker: Git Diff Files vs master" })

-- User commands
vim.api.nvim_create_user_command('GitDiffMaster', function()
  vim.cmd('tabnew')
  vim.cmd('Git ++curwin diff origin/master')
end, { desc = "Open git diff against origin/master" })

vim.api.nvim_create_user_command('GitDiffFiles', git_diff_files_master, { desc = "Show git diff files in picker" })

-- Picker keymappings (replacing Telescope)
local picker = require("snacks").picker

-- Function to show recent files filtered by current directory
local function recent_files_in_cwd()
  picker.recent({ filter = { cwd = true } })
end
vim.keymap.set('n', '<leader>ff', function() picker.files() end, { desc = 'Find Files' })
vim.keymap.set('n', '<leader>fg', function() picker.grep() end, { desc = 'Live Grep' })
vim.keymap.set('n', '<leader>fw', function() picker.grep_word() end, { desc = 'Grep Word' })
vim.keymap.set('n', '<leader>fb', function() picker.buffers() end, { desc = 'Buffers' })
vim.keymap.set('n', '<leader>fh', function() picker.help() end, { desc = 'Help Tags' })
vim.keymap.set('n', '<leader>fr', function() picker.lsp_references() end, { desc = 'LSP References' })
vim.keymap.set('n', '<leader>fi', function() picker.lsp_incoming_calls() end, { desc = 'LSP Incoming Calls' })
vim.keymap.set('n', '<leader>k', function() picker.lsp_symbols() end, { desc = 'LSP Document Symbols' })
vim.keymap.set('n', '<leader>j', recent_files_in_cwd, { desc = 'Recent Files' })
vim.keymap.set('n', '<leader>?', recent_files_in_cwd, { desc = 'Recent Files' })
vim.keymap.set('n', '<leader>/', function() picker.lines() end, { desc = 'Search in current buffer' })
vim.keymap.set('n', '<leader>fk', function() picker.keymaps() end, { desc = 'Keymaps' })
