local api = vim.api
local util = require 'vim.lsp.util'

local M = {}

local hover_messages = {}

M.set_decoration = function(bufnr, decoration_ns, decoration, color)
  local line = decoration.range["end"].line
  local text = decoration.renderOptions.after.contentText
  local virt_texts = {}
  table.insert(virt_texts, {text, color})
  api.nvim_buf_set_virtual_text(bufnr, decoration_ns, line, virt_texts, {})
end

M.store_hover_message = function(decoration)
  local hover_line = decoration.range["end"].line + 1
  local hover_message  = util.convert_input_to_markdown_lines(decoration.hoverMessage)
  hover_message = util.trim_empty_lines(hover_message)
  hover_messages[hover_line] = hover_message
end

M.show_hover_message = function()
  local row, _ = unpack(api.nvim_win_get_cursor(0))
  local hover_message = hover_messages[row]

  if hover_message == nil then
    return
  end

  local bufnr, winnr = util.fancy_floating_markdown(hover_message, {
    pad_left = 1; pad_right = 1;
  })
  util.close_preview_autocmd({"CursorMoved", "BufHidden", "InsertCharPre"}, winnr)
  local hover_len = #api.nvim_buf_get_lines(bufnr,0,-1,false)[1]
  local win_width = api.nvim_win_get_width(0)
  if hover_len > win_width then
      api.nvim_win_set_width(winnr,math.min(hover_len,win_width))
      api.nvim_win_set_height(winnr,math.ceil(hover_len/win_width))
      vim.wo[winnr].wrap = true -- luacheck: ignore 122
  end
end

M.clear_hover_messages = function()
  hover_messages = {}
end

return M
