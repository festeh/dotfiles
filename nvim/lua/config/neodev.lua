require("neodev").setup({
  override = function(root_dir, library)
    library.enabled = true
    library.plugins = true
  end,
})
