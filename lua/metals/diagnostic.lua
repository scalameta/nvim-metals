local api = vim.api
local lsp = require'vim.lsp'

local M = {}

--[[
  Fills the quick-fix with all the current LSP buffer diagnostics and opens it
  WARNING: The diagnostic quickfix list WILL ONLY be refreshed when this function is called,
    as opposed to diagnostic-nvim controlled location lists that gets updated in real time.
--]]
M.open_all_diagnostics = function()
  lsp.util.set_qflist(M.get_all_lsp_diagnostics_as_qfitems())
  api.nvim_command("copen")
  api.nvim_command("wincmd p")
end

-- Collects all LSP buffer diagnostic lists and flattens them into a quick-fix item list
M.get_all_lsp_diagnostics_as_qfitems = function()
  local qfitems = {}
  for bufnr, diagnostics in pairs(lsp.util.diagnostics_by_buf) do
    local uri = vim.uri_from_bufnr(bufnr)
    for _, d in ipairs(diagnostics) do
      local item = {
        bufrn = bufnr,
        filename = vim.uri_to_fname(uri),
        text  = d.message,
        lnum  = d.range.start.line + 1,
        col   = d.range.start.character + 1
      }
      if d.severity == 1 then
        item.type = 'E'
      elseif d.severity == 2 then
        item.type = 'W'
      end
      table.insert(qfitems, item)
    end
  end
  return qfitems
end

return M
