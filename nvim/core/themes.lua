local M = {}
M.colorscheme2dir = {
    onedark = "onedarkpro.nvim",
    edge = "edge",
    sonokai = "sonokai",
    gruvbox_material = "gruvbox-material",
    nord = "nord.nvim",
    everforest = "everforest",
    nightfox = "nightfox.nvim",
    kanagawa = "kanagawa.nvim",
    catppuccin = "catppuccin",
    rose_pine = "rose-pine",
    onedarkpro = "onedarkpro.nvim",
    monokai = "monokai.nvim",
    material = "material.nvim",
}

M.gruvbox8 = function()
    -- Italic options should be put before colorscheme setting,
    -- see https://github.com/morhetz/gruvbox/wiki/Terminal-specific#1-italics-is-disabled
    vim.g.gruvbox_italics = 0
    vim.g.gruvbox_italicize_strings = 0
    vim.g.gruvbox_filetype_hi_groups = 1
    vim.g.gruvbox_plugin_hi_groups = 1

    vim.cmd([[colorscheme gruvbox8_hard]])
end

M.onedark = function()
    vim.cmd([[colorscheme onedark]])
end

M.edge = function()
    vim.g.edge_enable_italic = 0
    vim.g.edge_better_performance = 1

    vim.cmd([[colorscheme edge]])
end

M.sonokai = function()
    vim.g.sonokai_enable_italic = 0
    vim.g.sonokai_better_performance = 1

    vim.cmd([[colorscheme sonokai]])
end

M.gruvbox_material = function()
    -- foreground option can be material, mix, or original
    vim.g.gruvbox_material_foreground = "material"
    --background option can be hard, medium, soft
    vim.g.gruvbox_material_background = "soft"
    vim.g.gruvbox_material_enable_italic = 0
    vim.g.gruvbox_material_better_performance = 1

    vim.cmd([[colorscheme gruvbox-material]])
end

M.nord = function()
    vim.cmd([[colorscheme nord]])
end

M.doom_one = function()
    vim.cmd([[colorscheme doom-one]])
end

M.everforest = function()
    vim.g.everforest_enable_italic = 0
    vim.g.everforest_better_performance = 1

    vim.cmd([[colorscheme everforest]])
end

M.nightfox = function()
    vim.cmd([[colorscheme nordfox]])
end

M.kanagawa = function()
    vim.cmd([[colorscheme kanagawa]])
end

M.catppuccin = function()
    -- available option: latte, frappe, macchiato, mocha
    vim.g.catppuccin_flavour = "frappe"

    require("catppuccin").setup()

    vim.cmd([[colorscheme catppuccin]])
end

M.rose_pine = function()
    require('rose-pine').setup({
        --- @usage 'main' | 'moon'
        dark_variant = 'moon',
    })

    -- set colorscheme after options
    vim.cmd('colorscheme rose-pine')
end

M.onedarkpro = function()
    -- set colorscheme after options
    vim.cmd('colorscheme onedark_vivid')
end

M.monokai = function()
    vim.cmd('colorscheme monokai_pro')
end

M.material = function()
    vim.g.material_style = "oceanic"
    vim.cmd('colorscheme material')
end

function rand_int(low, high)
    -- Use lua to generate random int, see also: https://stackoverflow.com/a/20157671/6064933
    math.randomseed(os.time())

    return math.random(low, high)
end

function rand_element(seq)
    local idx = rand_int(1, #seq)

    return seq[idx]
end

function add_pack(name)
    local status, error = pcall(vim.cmd, "packadd " .. name)

    return status
end

--- Use a random colorscheme from the pre-defined list of colorschemes.
M.rand_colorscheme = function()
    local colorscheme = rand_element(vim.tbl_keys(M.colorscheme2dir))
    if not vim.tbl_contains(vim.tbl_keys(M), colorscheme) then
        local msg = "Invalid colorscheme: " .. colorscheme
        print(vim.inspect(vim.tbl_keys(M)))
        vim.notify(msg, vim.log.levels.ERROR, { title = "nvim-config" })

        return
    end

    -- Load the colorscheme, because all the colorschemes are declared as opt plugins, so the colorscheme isn't loaded yet.
    local status = add_pack(M.colorscheme2dir[colorscheme])

    if not status then
        local msg = string.format("Colorscheme %s is not installed. Run PackerSync to install.", colorscheme)
        vim.notify(msg, vim.log.levels.ERROR, { title = "nvim-config" })

        return
    end

    -- Load the colorscheme and its settings
    M[colorscheme]()

    local msg = "Colorscheme: " .. colorscheme

    vim.notify(msg, vim.log.levels.INFO, { title = "nvim-config" })
end

-- Load a random colorscheme
M.rand_colorscheme()