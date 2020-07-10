local api = vim.api

--[[
  Facilities to help modularize the metals plugin config
--]]
local M = {}

M.auto_commands = function()
  api.nvim_command [[augroup NvimMetals]]
    api.nvim_command [[autocmd BufEnter <buffer> lua require'metals'.did_focus()]]
  api.nvim_command [[augroup end]]
end

return M
