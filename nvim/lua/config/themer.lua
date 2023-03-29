require("themer").setup({})
require("telescope").load_extension("themes")


local function get_random_theme()
  local themes = vim.fn.getcompletion("themer_", "color")
  for i, t in pairs(themes) do
    themes[i] = t:gsub("themer_", "")
  end
  local random_theme = themes[math.random(1, #themes)]
  print("Random theme: " .. random_theme)
  require("themer").setup({ colorscheme = random_theme })
end

vim.api.nvim_create_user_command("RandomTheme", get_random_theme, {})
