local resession = require("resession")
resession.setup()

local group = vim.api.nvim_create_augroup("ConfigResession", { clear = true })

local function is_empty_start_buffer()
  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].buftype ~= "" or vim.api.nvim_buf_get_name(buf) ~= "" or vim.bo[buf].modified then
    return false
  end
  if
    vim.api.nvim_buf_line_count(buf) ~= 1 or vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] ~= ""
  then
    return false
  end
  for _, other in ipairs(vim.api.nvim_list_bufs()) do
    if other ~= buf and vim.bo[other].buflisted then return false end
  end
  return true
end

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
  group = group,
  callback = function()
    -- Only load the session if nvim was started with no args
    if #vim.api.nvim_list_uis() > 0 and vim.fn.argc(-1) == 0 then
      resession.load(get_session_name(), { dir = "dirsession", silence_errors = true })
      -- Check if we are in the default empty buffer state after attempting to load a session
      if is_empty_start_buffer() then
        local snacks_ok, snacks = pcall(require, "snacks")
        if snacks_ok then snacks.picker.files() end
      end
    end
  end,
})

vim.api.nvim_create_autocmd("VimLeavePre", {
  group = group,
  callback = function()
    if #vim.api.nvim_list_uis() > 0 then
      resession.save(get_session_name(), { dir = "dirsession", notify = false })
    end
  end,
})
