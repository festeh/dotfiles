function _G.ReloadConfig()
-- Add modules here
local modules = {
  "options",
  "keymap",
  "plugins.treesitter",
  "plugins.gitsigns",
  "plugins.whichkey",
}
  for k, v in pairs(modules) do
      package.loaded[v] = nil
      require(v)
  end

  -- dofile(vim.env.MYVIMRC)
  vim.notify("Nvim configuration reloaded!", vim.log.levels.INFO)
end
