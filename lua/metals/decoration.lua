local api = vim.api
local lsp = require("vim.lsp")

local M = {}

local hover_messages = {}

M.set_decoration = function(bufnr, decoration_ns, decoration, color)
  local line = decoration.range["end"].line
  local text = decoration.renderOptions.after.contentText
  local virt_texts = {}
  table.insert(virt_texts, { text, color })
  api.nvim_buf_set_virtual_text(bufnr, decoration_ns, line, virt_texts, {})
end

M.store_hover_message = function(decoration)
  local hover_line = decoration.range["end"].line + 1
  local hover_message = lsp.util.convert_input_to_markdown_lines(decoration.hoverMessage)
  hover_message = lsp.util.trim_empty_lines(hover_message)
  hover_messages[hover_line] = hover_message
end

M.worksheet_hover = function()
  local row, _ = unpack(api.nvim_win_get_cursor(0))
  local hover_message = hover_messages[row]

  if hover_message == nil then
    return
  end

  local _, winnr = lsp.util.fancy_floating_markdown(hover_message, { pad_left = 1, pad_right = 1 })

  lsp.util.close_preview_autocmd({ "CursorMoved", "BufHidden", "InsertCharPre" }, winnr)
end

M.clear_hover_messages = function()
  hover_messages = {}
end

return M
