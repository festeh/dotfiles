require('lualine').setup {
    options = { fmt = string.lower },
    sections = { lualine_a = {
        { 'mode', fmt = function(str) return str:sub(1, 1) end }
    },
        lualine_b = { 'branch' } }
}
