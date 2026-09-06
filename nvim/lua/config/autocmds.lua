local group = vim.api.nvim_create_augroup("ConfigEditor", { clear = true })

-- Group filetypes by indentation width instead of repeating autocmd commands.
for width, filetypes in pairs({
  [2] = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
  [4] = { "c", "cpp", "bzl", "rust" },
}) do
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = filetypes,
    callback = function(event)
      vim.bo[event.buf].shiftwidth = width
      vim.bo[event.buf].tabstop = width
    end,
  })
end

vim.api.nvim_create_autocmd("UIEnter", {
  group = group,
  callback = function()
    local client = vim.api.nvim_get_chan_info(vim.v.event.chan).client
    if client and (client.name or ""):lower():find("firenvim", 1, true) and vim.o.lines < 10 then
      vim.o.lines = 10
    end
  end,
})
