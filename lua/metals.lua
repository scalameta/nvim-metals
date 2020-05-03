local vim = vim
local M = {}

local function execute_command(command, callback)
  vim.lsp.buf_request(0, 'workspace/executeCommand', command, function(err, _, resp)
    if callback then
      callback(err, resp)
    elseif err then
      print('Could not execute command: ' .. err.message)
    end
  end)
end

M.build_connect = function()
  execute_command({
    command = 'metals.build-connect';
  })
end

M.build_import = function()
   execute_command({
    command = "metals.build-import";
  })
end

M.build_restart = function()
  execute_command({
    command = 'metals.build-restart';
  })
end

M.compile_cascade = function()
  M.execute_command({
    command = 'metals.compile-cascade';
  })
end

M.doctor_run = function()
  M.execute_command({
    command = 'metals.doctor-run';
  })
end

M.logs_toggle = function()
  local bufs = vim.api.nvim_list_bufs()
  for _,v in ipairs(bufs) do
    local buftype = vim.api.nvim_buf_get_option(v, 'buftype')
    if buftype == "terminal" then
      print('Logs are already opened. Try an :ls to see where it is.')
      return
    end
  end
  -- Only open them if a terminal isn't already open
  vim.api.nvim_command [[vsp term://tail -f .metals/metals.log]]
end

M.sources_scan = function()
  execute_command({
    command = 'metals.sources-scan';
  })
end

return M
