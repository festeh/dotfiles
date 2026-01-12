require'fzf-lua'.setup {
  keymap = {
    builtin = {
      ["<A-p>"]      = "toggle-preview-wrap",
    },
    fzf = {
      ["ctrl-z"]     = "abort",
      ["ctrl-u"]     = "unix-line-discard",
      ["ctrl-f"]     = "half-page-down",
      ["ctrl-b"]     = "half-page-up",
      ["ctrl-a"]     = "beginning-of-line",
      ["ctrl-e"]     = "end-of-line",
      ["alt-a"]      = "toggle-all",
      ["ctrl-/"]     = "toggle-wrap",          -- toggle main list wrap
      ["alt-p"]      = "toggle-preview-wrap",  -- toggle preview wrap
      ["f4"]         = "toggle-preview",
      ["shift-down"] = "preview-page-down",
      ["shift-up"]   = "preview-page-up",
      ["tab"]        = "down",
      ["shift-tab"]  = "up",
    }
  }
}


vim.keymap.set({"n", "i", "x"}, "<C-p>", function()
  require('fzf-lua').files({ winopts = { fullscreen = true } })
end)
vim.keymap.set({"n"}, "<Leader>p",  "<cmd>lua require('fzf-lua').live_grep()<CR>")

