require('blink.cmp').setup({
  keymap = {
    preset = 'default',
    ['<Tab>'] = false,
    ['<S-Tab>'] = false,
  },
  completion = { documentation = { auto_show = true } },
  sources = {
    default = { 'lsp', 'path', 'buffer' },
    transform_items = function(_, items)
      -- Some servers return snippets even when snippetSupport is false.
      return vim.tbl_filter(function(item)
        return item.kind ~= vim.lsp.protocol.CompletionItemKind.Snippet
          and item.insertTextFormat ~= vim.lsp.protocol.InsertTextFormat.Snippet
      end, items)
    end,
  },
})
