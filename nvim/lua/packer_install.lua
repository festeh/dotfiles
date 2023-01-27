local api = vim.api
local fn = vim.fn

local M = {}

vim.g.plugin_home = fn.stdpath('data')..'/site/pack/packer_plugins'

function ensure_packer()
  local install_path = vim.g.plugin_home..'/opt/packer.nvim'
  if fn.empty(fn.glob(install_path)) > 0 then
	api.nvim_echo({ { "Installing packer.nvim", "Type" } }, true, {})
	local packer_repo = "https://github.com/wbthomason/packer.nvim"
	local install_cmd = string.format("!git clone --depth=1 %s %s", packer_repo, install_path)
    vim.cmd(install_cmd)
    return true
  end
  return false
end

ensure_packer()

vim.cmd("packadd packer.nvim")

