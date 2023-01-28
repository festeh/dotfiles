require("bufferline").setup {
  options = {
    persist_buffer_sort = true,
    sort_by = function(buf_a, buf_b)
      return vim.fn.getbufinfo(buf_a.id)[1].lastused > vim.fn.getbufinfo(buf_b.id)[1].lastused
    end,
    custom_filter = function(buf)
      if vim.fn.bufname(buf) == "" then
        return false
      end
      return true
    end
  },
  highlights = {
    buffer_selected = {
      italic = false,
      bold = true
    }
  }
}

vim.keymap.set("n", "<Leader>u", "<Cmd>BufferLinePick<cr>")
