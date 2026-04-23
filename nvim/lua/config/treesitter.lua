local ensure_installed = {
  'bash', 'c', 'css', 'go', 'html', 'javascript', 'jinja', 'json',
  'json5', 'kotlin', 'lua', 'markdown', 'markdown_inline', 'python',
  'rust', 'svelte', 'toml', 'tsx', 'typescript', 'vala', 'vim',
  'vimdoc', 'yaml',
}

local ts = require('nvim-treesitter')

local installed = ts.get_installed('parsers')
local missing = vim.tbl_filter(function(p)
  return not vim.tbl_contains(installed, p)
end, ensure_installed)
if #missing > 0 then
  ts.install(missing)
end

vim.api.nvim_create_autocmd('FileType', {
  callback = function(args)
    local lang = vim.treesitter.language.get_lang(args.match)
    if lang and vim.tbl_contains(ts.get_installed('parsers'), lang) then
      pcall(vim.treesitter.start, args.buf, lang)
      vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    end
  end,
})
