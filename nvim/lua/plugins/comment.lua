require'Comment'.setup(
{toggler = {
        line = 'gcc',
        block = 'gbc',
    },
    opleader = {
        line = '<A-/>',
        block = 'gb',
    },
}
)

local opt = { expr = true, remap = true, replace_keycodes = false }
vim.keymap.set('n', '<A-/>', "v:count == 0 ? '<Plug>(comment_toggle_current_linewise)' : '<Plug>(comment_toggle_linewise_count)'", opt)
