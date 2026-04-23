require('nvim-treesitter-textobjects').setup {
  select = {
    lookahead = true,
    selection_modes = {
      ['@parameter.outer'] = 'v',
      ['@function.outer']  = 'V',
      ['@class.outer']     = '<c-v>',
    },
    include_surrounding_whitespace = true,
  },
  move = {
    set_jumps = true,
  },
}

local select = require('nvim-treesitter-textobjects.select')
local move   = require('nvim-treesitter-textobjects.move')

local function map(mode, lhs, rhs, desc)
  vim.keymap.set(mode, lhs, rhs, { desc = desc, silent = true })
end

-- Select
map({ 'x', 'o' }, 'ac', function() select.select_textobject('@class.outer', 'textobjects') end, 'Select outer class')
map({ 'x', 'o' }, 'ic', function() select.select_textobject('@class.inner', 'textobjects') end, 'Select inner class')

-- Move: next start
map({ 'n', 'x', 'o' }, ']f', function() move.goto_next_start('@call.outer', 'textobjects') end,        'Next function call start')
map({ 'n', 'x', 'o' }, ']m', function() move.goto_next_start('@function.outer', 'textobjects') end,    'Next function def start')
map({ 'n', 'x', 'o' }, ']c', function() move.goto_next_start('@class.outer', 'textobjects') end,       'Next class start')
map({ 'n', 'x', 'o' }, ']i', function() move.goto_next_start('@conditional.outer', 'textobjects') end, 'Next conditional start')
map({ 'n', 'x', 'o' }, ']l', function() move.goto_next_start('@loop.outer', 'textobjects') end,        'Next loop start')
map({ 'n', 'x', 'o' }, ']s', function() move.goto_next_start('@scope', 'locals') end,                  'Next scope')
map({ 'n', 'x', 'o' }, ']z', function() move.goto_next_start('@fold', 'folds') end,                    'Next fold')

-- Move: previous start
map({ 'n', 'x', 'o' }, '[f', function() move.goto_previous_start('@call.outer', 'textobjects') end,        'Prev function call start')
map({ 'n', 'x', 'o' }, '[m', function() move.goto_previous_start('@function.outer', 'textobjects') end,    'Prev function def start')
map({ 'n', 'x', 'o' }, '[c', function() move.goto_previous_start('@class.outer', 'textobjects') end,       'Prev class start')
map({ 'n', 'x', 'o' }, '[i', function() move.goto_previous_start('@conditional.outer', 'textobjects') end, 'Prev conditional start')
map({ 'n', 'x', 'o' }, '[l', function() move.goto_previous_start('@loop.outer', 'textobjects') end,        'Prev loop start')

-- Move: next/prev end (function or class — whichever comes first)
local function goto_end(dir, captures)
  return function()
    local fn = dir == 'next' and move.goto_next_end or move.goto_previous_end
    fn(captures, 'textobjects')
  end
end

map({ 'n', 'x', 'o' }, ']M', goto_end('next', { '@function.outer', '@class.outer' }),     'End of next function/class')
map({ 'n', 'x', 'o' }, '[M', goto_end('prev', { '@function.outer', '@class.outer' }),     'End of previous function/class')
