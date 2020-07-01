--[[
  Facilities to help modularize the metals plugin config
--]]

local M = {}

M.auto_commands = function()
  vim.api.nvim_command [[augroup NvimMetals]]
    vim.api.nvim_command [[autocmd BufEnter <buffer> lua require'metals'.did_focus()]]
  vim.api.nvim_command [[augroup end]]
end

return M
