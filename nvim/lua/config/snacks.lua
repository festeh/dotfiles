require("snacks").setup(
  {
    picker = { enabled = true },
    explorer = { enabled = true },
    gitbrowse = { enabled = true },
    git = { enabled = true },
    lazygit = { enabled = true },
    input = { enabled = true },  -- Better vim.ui.input
  }
)

-- Explorer command
vim.api.nvim_create_user_command('Explorer', function()
  Snacks.picker.explorer({ diagnostics = false })
end, {})

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

-- Function to jump from delta diff to actual file
local function jump_to_file_from_delta()
  local current_line = vim.api.nvim_get_current_line()
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]

  -- Try to extract line number from current line
  -- Delta format with line-numbers: " 26 ⋮ 26 │code" or "    ⋮ 29 │code" (added) or " 32 ⋮    │code" (deleted)
  local line_num = nil

  -- Try to match unchanged line format: " 26 ⋮ 26 │"
  line_num = current_line:match("%s*%d+%s*⋮%s*(%d+)%s*│")

  -- If not found, try added line format: "    ⋮ 29 │"
  if not line_num then
    line_num = current_line:match("%s*⋮%s*(%d+)%s*│")
  end

  if not line_num then
    vim.notify("No line number found on current line (might be a deleted line)", vim.log.levels.WARN)
    return
  end

  -- Search backwards for file name (format: "apps/path/to/file.rs" or "added: path/to/file.rs")
  local file_path = nil
  for i = cursor_line, 1, -1 do
    local line = vim.api.nvim_buf_get_lines(0, i - 1, i, false)[1]
    -- Look for file path - should be on a line by itself with path/to/file.ext format
    if line and line:match("^[a-zA-Z_].*%.%w+%s*$") and line:match("/") then
      -- Strip leading/trailing whitespace and delta prefixes (added:, removed:, modified:, renamed:)
      file_path = line:gsub("^%s+", ""):gsub("%s+$", "")
      file_path = file_path:gsub("^added:%s*", ""):gsub("^removed:%s*", ""):gsub("^modified:%s*", ""):gsub("^renamed:%s*", "")
      break
    end
  end

  if not file_path then
    vim.notify("Could not find file path", vim.log.levels.WARN)
    return
  end

  -- Open the file at the line number
  vim.cmd('edit +' .. line_num .. ' ' .. vim.fn.fnameescape(file_path))
end

-- vim-fugitive unified diff keymappings with delta
vim.keymap.set("n", "<leader>gM", function()
  -- Capture current file and line before opening diff
  local current_file = vim.fn.expand('%:p')
  local current_line = vim.fn.line('.')
  local has_context = current_file ~= '' and vim.fn.filereadable(current_file) == 1

  vim.cmd('tabnew')
  local bufnr = vim.api.nvim_get_current_buf()
  local job_id = vim.fn.termopen('git diff origin/master | delta --paging=never --line-numbers', {
    on_exit = function()
      -- Keep buffer open after process exits
      vim.bo[bufnr].modified = false
      -- Switch to normal mode when process finishes
      vim.cmd('stopinsert')
      -- Set up keybinding to jump to file
      vim.api.nvim_buf_set_keymap(bufnr, 'n', 'gf', '', {
        callback = jump_to_file_from_delta,
        noremap = true,
        silent = true,
        desc = "Jump to file at line"
      })
      vim.api.nvim_buf_set_keymap(bufnr, 'n', '<CR>', '', {
        callback = jump_to_file_from_delta,
        noremap = true,
        silent = true,
        desc = "Jump to file at line"
      })

      -- Try to jump to the current file and line in the diff
      if has_context then
        vim.schedule(function()
          -- Search for the file in the diff
          local file_pattern = vim.fn.fnamemodify(current_file, ':t')  -- just filename
          local search_result = vim.fn.search(file_pattern, 'w')

          if search_result > 0 then
            -- File found, now try to find the line number
            -- Look for lines with format " XXX ⋮ XXX │" where XXX is close to current_line
            local buf_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
            local best_match = nil
            local best_diff = math.huge

            for i = search_result, math.min(search_result + 500, #buf_lines) do
              local line = buf_lines[i]
              if line then
                -- Try to extract line number from delta format
                local line_num = line:match("%s*%d+%s*⋮%s*(%d+)%s*│")
                if not line_num then
                  line_num = line:match("%s*⋮%s*(%d+)%s*│")
                end

                if line_num then
                  local num = tonumber(line_num)
                  local diff = math.abs(num - current_line)
                  if diff < best_diff then
                    best_diff = diff
                    best_match = i
                  end
                  -- If we found exact match or very close, stop searching
                  if diff <= 2 then
                    break
                  end
                end

                -- Stop if we hit another file
                if line:match("^[a-zA-Z_].*%.%w+%s*$") and i > search_result then
                  break
                end
              end
            end

            if best_match and best_diff <= 10 then
              -- Add a small delay to ensure terminal is ready
              vim.defer_fn(function()
                -- Find the window showing our terminal buffer
                for _, win in ipairs(vim.api.nvim_list_wins()) do
                  if vim.api.nvim_win_get_buf(win) == bufnr then
                    vim.api.nvim_win_set_cursor(win, {best_match, 0})

                    -- Center the view
                    vim.api.nvim_win_call(win, function()
                      local height = vim.api.nvim_win_get_height(win)
                      local topline = math.max(1, best_match - math.floor(height / 2))
                      vim.fn.winrestview({topline = topline})
                    end)

                    break
                  end
                end
              end, 100)  -- 100ms delay
            end
          end
        end)
      end
    end
  })
end, { desc = "Git Diff origin/master with syntax highlighting" })

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

      -- Find the tab with delta diff terminal and switch to it
      local found = false
      for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
          local buf = vim.api.nvim_win_get_buf(win)
          local bufname = vim.api.nvim_buf_get_name(buf)
          -- Check if this is a terminal buffer with delta
          if vim.bo[buf].buftype == "terminal" and bufname:match("delta") then
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
        local bufnr = vim.api.nvim_get_current_buf()
        vim.fn.termopen('git diff origin/master | delta --paging=never --line-numbers', {
          on_exit = function()
            vim.bo[bufnr].modified = false
            vim.cmd('stopinsert')
            -- Set up keybindings
            vim.api.nvim_buf_set_keymap(bufnr, 'n', 'gf', '', {
              callback = jump_to_file_from_delta,
              noremap = true,
              silent = true,
            })
            vim.api.nvim_buf_set_keymap(bufnr, 'n', '<CR>', '', {
              callback = jump_to_file_from_delta,
              noremap = true,
              silent = true,
            })
          end
        })
      end

      -- Search for the file in the diff buffer
      vim.fn.feedkeys('/' .. vim.fn.escape(item.file, '/\\') .. '\n')
    end,
    title = "Git Diff Files (origin/master)",
  })
end

vim.keymap.set("n", "<leader>gF", git_diff_files_master, { desc = "Picker: Git Diff Files vs master" })

-- User commands
vim.api.nvim_create_user_command('GitDiffMaster', function()
  vim.cmd('tabnew')
  local bufnr = vim.api.nvim_get_current_buf()
  vim.fn.termopen('git diff origin/master | delta --paging=never --line-numbers', {
    on_exit = function()
      vim.bo[bufnr].modified = false
      vim.cmd('stopinsert')
      -- Set up keybindings
      vim.api.nvim_buf_set_keymap(bufnr, 'n', 'gf', '', {
        callback = jump_to_file_from_delta,
        noremap = true,
        silent = true,
      })
      vim.api.nvim_buf_set_keymap(bufnr, 'n', '<CR>', '', {
        callback = jump_to_file_from_delta,
        noremap = true,
        silent = true,
      })
    end
  })
end, { desc = "Open git diff against origin/master with syntax highlighting" })

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
