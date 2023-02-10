local dap = require("dap")

local path = vim.fn.glob(vim.fn.stdpath("data") .. "/mason/packages/codelldb/extension/") or ""
local codelldb_path = path .. "adapter/codelldb"
local liblldb_path = path .. "lldb/lib/liblldb.so"


dap.adapters.codelldb = {
  type = 'server',
  port = "${port}",
  executable = {
    -- CHANGE THIS to your path!
    command = codelldb_path,
    args = { "--port", "${port}" },

    -- On windows you may have to uncomment this:
    -- detached = false,
  }
}

dap.configurations.cpp = {
  {
    name = "Launch file",
    type = "codelldb",
    request = "launch",
    program = function()
      return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/', 'file')
    end,
    cwd = '${workspaceFolder}',
    stopOnEntry = false,
  },
}


dap.configurations.rust = dap.configurations.cpp
