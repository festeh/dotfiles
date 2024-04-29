local dap = require("dap")

local path = vim.fn.glob(vim.fn.stdpath("data") .. "/mason/packages/codelldb/extension/") or ""
local codelldb_path = path .. "adapter/codelldb"
local liblldb_path = path .. "lldb/lib/liblldb.so"

local opts = {}
vim.keymap.set("n", "<M-d>", dap.continue, opts)
vim.keymap.set("n", "<leader>i", dap.step_into, opts)
vim.keymap.set("n", "<leader>n", dap.step_over, opts)
vim.keymap.set("n", "<leader>o", dap.step_out, opts)

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

dap.configurations.lua = {
  {
    type = 'nlua',
    request = 'attach',
    name = "Attach to running Neovim instance",
  }
}

dap.adapters["local-lua"] = {
  type = "executable",
  command = "node",
  args = {
    "/home/dlipin/tmp/local-lua-debugger-vscode/extension/debugAdapter.js",
  },
  enrich_config = function(config, on_config)
    if not config["extensionPath"] then
      local c = vim.deepcopy(config)
      -- 💀 If this is missing or wrong you'll see
      -- "module 'lldebugger' not found" errors in the dap-repl when trying to launch a debug session
      c.extensionPath = "/home/dlipin/tmp/local-lua-debugger-vscode/"
      on_config(c)
    else
      on_config(config)
    end
  end,
}

dap.configurations.lua = {
  {
    name = 'Current file (local-lua-dbg, lua)',
    type = 'local-lua',
    request = 'launch',
    cwd = '${workspaceFolder}',
    program = {
      lua = 'nlua.lua',
      file = '${file}',
    },
    verbose = true,
    args = {},
  },
}

dap.adapters.python = {
  type = 'executable',
  command = 'python',
  args = { '-m', 'debugpy.adapter' },
}

dap.configurations.python = {
  {
    type = 'python',
    request = 'launch',
    name = "Launch file",
    program = "${file}",
    justMyCode = false,
    pythonPath = function()
      local cwd = vim.fn.getcwd()
      if vim.fn.executable('./venv/bin/python') == 1 then
        return './venv/bin/python'
      elseif vim.fn.executable('python') == 1 then
        return 'python'
      else
        return '/usr/bin/python'
      end
    end,
  },
}

dap.adapters.nlua = function(callback, config)
  callback({ type = 'server', host = config.host or "127.0.0.1", port = config.port or 8086 })
end
