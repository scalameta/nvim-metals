--[[
  Facilities to help modularize the metals plugin config
--]]

local M = {}

--[[ The only way to enable didSave with current LSP and metals
capabilities is to override after init. --]]
M.on_init = function(client, _)
  client.resolved_capabilities.text_document_save = true
end

M.auto_commands = function()
  vim.api.nvim_command [[augroup NvimMetals]]
    vim.api.nvim_command [[autocmd BufEnter <buffer> lua require'metals'.did_focus()]]
  vim.api.nvim_command [[augroup end]]
end

return M
