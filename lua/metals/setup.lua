--[[
  Facilities to help modularize the metals plugin config
--]]

local M = {}

--[[ The only way to enable didSave with current LSP and metals
capabilities is to override after init. --]]
M.on_init = function(client, _)
  client.resolved_capabilities.text_document_save = true
end

return M
