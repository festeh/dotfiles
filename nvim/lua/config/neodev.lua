require("neodev").setup({
  library = {
    enabled = true,
    types = true,
    plugins = {"plenary.nvim"}
  },
  override = function(root_dir, library)
    library.enabled = true
    library.plugins = {"plenary.nvim"}
  end,
})
