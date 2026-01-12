local resession = require("resession")
resession.setup()


local function get_session_name()
  local name = vim.fn.getcwd()
  local branch = vim.trim(vim.fn.system("git branch --show-current"))
  if vim.v.shell_error == 0 then
    return name .. branch
  else
    return name
  end
end

vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    -- Only load the session if nvim was started with no args
    if vim.fn.argc(-1) == 0 then
      resession.load(get_session_name(), { dir = "dirsession", silence_errors = true })
      -- Check if we are in the default empty buffer state after attempting to load a session
      local is_default_buffer = vim.fn.bufnr('$') == 1 and
                                vim.fn.line('$') == 1 and
                                vim.fn.empty(vim.fn.getline(1))
      if is_default_buffer then
        local snacks_ok, snacks = pcall(require, 'snacks')
        if snacks_ok then
          snacks.picker.files()
        end
      end
    end
  end,
})

vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    resession.save(get_session_name(), { dir = "dirsession", notify = false })
  end,
})
