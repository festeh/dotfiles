local dap = require("dap")

local function executable(name)
  local path = vim.fn.exepath(name)
  if path == "" then error(("Debugger %s is missing. Install it with :Mason."):format(name)) end
  return path
end

vim.keymap.set("n", "<M-d>", dap.continue, { desc = "Start or continue debugging" })
vim.keymap.set("n", "<leader>i", dap.step_into, { desc = "Debugger: step into" })
vim.keymap.set("n", "<leader>n", dap.step_over, { desc = "Debugger: step over" })
vim.keymap.set("n", "<leader>o", dap.step_out, { desc = "Debugger: step out" })

dap.adapters.codelldb = function(callback)
  callback({
    type = "server",
    port = "${port}",
    executable = {
      command = executable("codelldb"),
      args = { "--port", "${port}" },
    },
  })
end

dap.configurations.cpp = {
  {
    name = "Launch executable",
    type = "codelldb",
    request = "launch",
    program = function()
      local path = vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
      return path ~= "" and path or dap.ABORT
    end,
    cwd = "${workspaceFolder}",
    stopOnEntry = false,
  },
}
dap.configurations.c = vim.deepcopy(dap.configurations.cpp)

dap.adapters.nlua = function(callback, config)
  callback({ type = "server", host = config.host or "127.0.0.1", port = config.port or 8086 })
end

dap.configurations.lua = {
  {
    type = "nlua",
    request = "attach",
    name = "Attach to Neovim (OSV)",
    host = "127.0.0.1",
    port = 8086,
  },
}

-- Run this in the Neovim instance you want to debug, then attach from another.
vim.api.nvim_create_user_command("LuaDebugServer", function()
  require("osv").launch({ host = "127.0.0.1", port = 8086 })
end, { desc = "Start the Neovim Lua debugger on localhost:8086" })

dap.adapters.go = function(callback)
  callback({
    type = "server",
    port = "${port}",
    executable = {
      command = executable("dlv"),
      args = { "dap", "-l", "127.0.0.1:${port}" },
    },
  })
end

dap.configurations.go = {
  {
    type = "go",
    name = "Debug package",
    request = "launch",
    program = ".",
  },
}
