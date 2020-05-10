local vim = vim

local health_start = vim.fn["health#report_start"]
local health_ok = vim.fn['health#report_ok']

local M = {}

M.checkHealth = function()
  health_start('Checking Nvim Version')
  -- This needs to be called with the buffer we were in, no the health buffer
  local client = vim.inspect(vim.lsp.buf_get_clients(0))
  health_ok(client)
end

return M
