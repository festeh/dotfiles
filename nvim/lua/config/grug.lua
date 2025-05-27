local grug = require("grug-far")

grug.setup({
  keymaps = {
    close = {
      n = "<localleader>q"
    },
    refresh = {
      n = "<localleader>r"
    },
    historyOpen = {
      n = "<localleader>h"
    },
    pickHistoryEntry = { n = '<enter>' },
    help = { n = 'g?' },
    qflist = false,
    replace = {
      n = "<localleader>n",
    }
  }
})

local function close_grug()
  if grug.is_instance_open() then
    grug.hide_instance()
  end
end

local grug_args = {
  engines = {
    ripgrep = {
      extraArgs = "-i"
    }
  }
}

vim.keymap.set({ 'n', 'x' }, '<leader>s', function()
  close_grug()
  local args = vim.deepcopy(grug_args)
  args.prefills = { search = vim.fn.expand("<cword>") }
  grug.open(args)
end, { desc = 'grug-far: Search for current word under cursor' })


vim.keymap.set({ 'n', 'x' }, '<leader>S', function()
  close_grug()
  grug.open(grug_args)
end, { desc = 'grug-far: Search globally from scratch' })
