require("themer").setup({ enable_installer = true })
require("telescope").load_extension("themes")


local function get_random_theme()
  local themes = {
    "themer_amora", "themer_astron", "themer_ayu", "themer_ayu_dark", "themer_ayu_mirage", "themer_boo",
    "themer_catppuccin", "themer_darknight", "themer_doom_one", "themer_dracula", "themer_everforest",
    "themer_github_dark",
    "themer_github_dark_colorblind", "themer_github_light", "themer_gruvbox", "themer_gruvbox-material-dark-hard",
    "themer_gruvbox-material-dark-medium", "themer_gruvbox-material-dark-soft",
    "themer_javacafe", "themer_jellybeans",
    "themer_kanagawa", "themer_kurai", "themer_monokai", "themer_monokai_pro",
    "themer_monokai_vibrant",
    "themer_nightlamp", "themer_nord", "themer_onedark", "themer_onedark_deep", "themer_papa_dark", "themer_radium",
    "themer_rose_pine",
    -- "themer_rose_pine_dawn",
    "themer_rose_pine_moon", "themer_sakura", "themer_scery", "themer_shado",
    "themer_sonokai_deep", "themer_tokyodark", "themer_tokyonight", "themer_uwu"
  }
  for i, t in pairs(themes) do
    themes[i] = t:gsub("themer_", "")
  end
  local random_theme = themes[math.random(1, #themes)]
  print("Random theme: " .. random_theme)
  require("themer").setup({ colorscheme = random_theme })
end

get_random_theme()

vim.api.nvim_create_user_command("RandomTheme", get_random_theme, {})
