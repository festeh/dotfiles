require('mdeval').setup {
    --Don't ask before executing code blocks
    require_confirmation = false,
    eval_options = {}
}

vim.keymap.set('n', '<leader>c',
    "<cmd>lua require 'mdeval'.eval_code_block()<CR>",
    { silent = true, noremap = true })
