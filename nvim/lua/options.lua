-- TODO: add wildmenu wildopt settings
local options = {
    autoindent = true,
    autowrite = true, -- save file on buf change and make
    backup = false,
    clipboard = "unnamedplus",
    cmdheight = 1, -- one line for ex command
    completeopt = {"menuone", "noselect"}, -- autocomplete settings
    conceallevel = 2, -- TODO: find out why it should be 0 
    cursorline = true,
    expandtab = true,
    fileencoding = "utf-8",
    laststatus = 3,
    hlsearch = true,
    ignorecase = true,
    incsearch = true,
    mouse = "a",
    number = true,
    pumheight = 10, -- TODO: doesn't relly work, COQ overwrites this setting
    scrolloff = 8, -- position cursor so there's n lines above and below
    shiftwidth = 4,
    showmode = false,
    sidescrolloff = 8, -- position cursor so there's n lines above and below
    signcolumn = "auto", -- set to "yes" when need to debug
    smartcase = true,
    softtabstop = 4,
    splitbelow = true, -- always split below
    splitright = true, -- always split right
    swapfile = false,
    tabstop = 4,
    termguicolors = true,
    timeoutlen = 1000, -- time to wait end of composition(<Leader-r> for example) (ms)
    undodir = os.getenv("HOME") .. "/.config/nvim/undo",
    undofile = true,
    undolevels = 10000,
    updatetime = 100, -- faster completion
    wrap = false,
}

for k, v in pairs(options) do
  vim.opt[k] = v
end
