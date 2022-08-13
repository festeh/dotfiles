local wk = require("which-key")

wk.setup {
    triggers = {}
}
local opts = {
    mode = "n", -- Normal mode
    prefix = "<leader>",
    buffer = nil, -- Global mappings. Specify a buffer number for buffer local mappings
    silent = true, -- use `silent` when creating keymaps
    noremap = true, -- use `noremap` when creating keymaps
    nowait = false, -- use `nowait` when creating keymaps
  }
wk.register({
    ["q"] = { "<cmd>q!<CR>", "Quit" },
    b = {
         name = "Buffer",
         c = { "<Cmd>bd!<Cr>", "Close current buffer" },
         D = { "<Cmd>%bd|e#|bd#<Cr>", "Delete all buffers" },
       },
    c = {
        name = "Close",
        c = { "<cmd>qall!<CR>", "Close all" },
        t = { "<Cmd>tabclose<Cr>", "Close tab" },
    },
        g = { "<Cmd>Git<CR>", "Open git"  },
    ["?"] = { "<Cmd>WhichKey <Leader><CR>", "Open Whichkey"}
}, opts)
