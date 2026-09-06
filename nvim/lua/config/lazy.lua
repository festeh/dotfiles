local M = {}

-- Keep substantial plugin setup in config modules; small options live in specs.
function M.config(module)
  return function()
    require("config." .. module)
  end
end

function M.setup()
  local source = vim.uv.fs_realpath(debug.getinfo(1, "S").source:sub(2))
  local root = vim.fn.fnamemodify(source, ":h:h:h")
  local lockfile = root .. "/lazy-lock.json"
  local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
  if not vim.uv.fs_stat(lazypath) then
    local lock = vim.json.decode(table.concat(vim.fn.readfile(lockfile), "\n"))
    for _, command in ipairs({
      { "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", lazypath },
      { "git", "-C", lazypath, "checkout", "--detach", lock["lazy.nvim"].commit },
    }) do
      local output = vim.fn.system(command)
      if vim.v.shell_error ~= 0 then error("Failed to bootstrap lazy.nvim:\n" .. output) end
    end
  end
  vim.opt.rtp:prepend(lazypath)
  require("lazy").setup("plugins", {
    lockfile = lockfile,
    dev = { path = "~/projects/" },
  })
end

return M
