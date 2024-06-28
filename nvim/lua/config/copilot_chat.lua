local opts = {
  -- debug = true, -- Enable debugging
  -- See Configuration section for rest
  window = {
    layout = 'float',
    relative = 'cursor',
    width = 1.0,
    height = 0.9,
    row = 1
  },
  mappings = {
    reset = {
      normal = "<C-x>",
      insert = "<C-x>",
    },
  }
}

require("CopilotChat").setup(opts)
