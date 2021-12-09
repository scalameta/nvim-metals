local api = vim.api

local M = {}

-- Collects all LSP buffer diagnostic lists and flattens them into a quick-fix item list
local function get_all_lsp_diagnostics_as_qfitems()
  local qfitems = {}
  -- Temporary array for warnings, so they are appended after errors
  local warnings = {}

  local all_diags = vim.diagnostic.get()

  for _, d in ipairs(all_diags) do
    local uri = vim.uri_from_bufnr(d.bufnr)
    local item = {
      bufrn = d.bufnr,
      filename = vim.uri_to_fname(uri),
      text = d.message,
      lnum = d.lnum,
      col = d.col,
    }
    if d.severity == 1 then
      item.type = "E"
      qfitems[#qfitems + 1] = item
    elseif d.severity == 2 then
      item.type = "W"
      warnings[#warnings + 1] = item
    end
  end

  for i = 1, #warnings do
    qfitems[#qfitems + 1] = warnings[i]
  end
  return qfitems
end

--  Fills the quick-fix with all the current LSP workspace diagnostics and
--  opens it.
--
--  WARNING: The diagnostic quickfix list WILL ONLY be refreshed when this
--  function is called, as opposed to diagnostic-nvim controlled location lists
--  that gets updated in real time.
M.open_all_diagnostics = function()
  local all_diagnostics = get_all_lsp_diagnostics_as_qfitems()
  if #all_diagnostics > 0 then
    vim.diagnostic.setqflist(all_diagnostics)
    api.nvim_command("copen")
    api.nvim_command("wincmd p")
  else
    api.nvim_command("cclose")
  end
end

return M
