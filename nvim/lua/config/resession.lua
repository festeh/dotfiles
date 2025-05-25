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
      local loaded_successfully = resession.load(get_session_name(), { dir = "dirsession", silence_errors = true })
      if not loaded_successfully then
        local fzf_lua_ok, _ = pcall(require, 'fzf-lua')
        if fzf_lua_ok then
          require('fzf-lua').files()
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
