local api = vim.api

local modules = {
  "globals.lua",
  "options.lua",
  "mappings.lua",
}

local config_dir = vim.fn.stdpath("config")

vim.cmd([[
  function! s:IsFirenvimActive(event) abort
    if !exists('*nvim_get_chan_info')
      return 0
    endif
    let l:ui = nvim_get_chan_info(a:event.chan)
    return has_key(l:ui, 'client') && has_key(l:ui.client, 'name') &&
        \ l:ui.client.name =~? 'Firenvim'
  endfunction

  function! OnUIEnter(event) abort
    if s:IsFirenvimActive(a:event) && &lines < 10
      set lines=10
    endif
  endfunction

  augroup FirenvimUser
    autocmd!
    autocmd UIEnter * call OnUIEnter(deepcopy(v:event))
  augroup end
]])

for _, module in ipairs(modules) do
  local cmd = string.format("source %s/core/%s", config_dir, module)
  vim.api.nvim_exec(cmd, false)
end

-- require("plugins")
require("lazy_plugins")

local ok, res = pcall(vim.cmd, "colorscheme catppuccin-mocha")
