vim.g.neoformat_enabled_python = { 'yapf' }
vim.g.neoformat_enabled_javascript = { 'prettier' }
vim.g.neoformat_enabled_css = { 'prettier' }
vim.g.neoformat_enabled_html = { 'prettier' }

local ext_to_lang = {
  -- py = "python",
  lua = "lua",
  -- js = "javascript",
  -- css = "css",
  -- html = "html",
}

local function format()
  local buf = vim.api.nvim_get_current_buf()
  local name = vim.api.nvim_buf_get_name(buf)
  local ext = name:match("%.(%w+)$")
  local lang = ext_to_lang[ext]
  if lang then
    local key = "neoformat_enabled_" .. lang
    if vim.g[key] then
      vim.cmd("Neoformat")
      return
    end
  end
  vim.lsp.buf.format()
end

vim.keymap.set('n', '<leader>m', format, { desc = "Format buf with Neoformat or ls" })
