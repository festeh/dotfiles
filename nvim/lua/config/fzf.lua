require'fzf-lua'.setup {
  keymap = {
    fzf = {
      ["ctrl-z"]     = "abort",
      ["ctrl-u"]     = "unix-line-discard",
      ["ctrl-f"]     = "half-page-down",
      ["ctrl-b"]     = "half-page-up",
      ["ctrl-a"]     = "beginning-of-line",
      ["ctrl-e"]     = "end-of-line",
      ["alt-a"]      = "toggle-all",
      -- Only valid with fzf previewers (bat/cat/git/etc)
      ["f3"]         = "toggle-preview-wrap",
      ["f4"]         = "toggle-preview",
      ["shift-down"] = "preview-page-down",
      ["shift-up"]   = "preview-page-up",
      ["tab"]        = "down",
      ["shift-tab"]  = "up",
    }
  }
}


vim.keymap.set({"n", "i", "x"}, "<C-p>",  "<cmd>lua require('fzf-lua').files()<CR>")
vim.keymap.set({"n"}, "<Leader>p",  "<cmd>lua require('fzf-lua').live_grep()<CR>")
