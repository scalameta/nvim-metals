local vim = vim
local M = {}

function M.execute_command(command, callback)
  vim.lsp.buf_request(0, 'workspace/executeCommand', command, function(err, _, resp)
    if callback then
      callback(err, resp)
    elseif err then
      print('Could not execute command: ' .. err.message)
    end
  end)
end

function M.build_import()
  M.execute_command({
    command = "metals.build-import";
  })
end

function M.build_connect()
  M.execute_command({
    command = 'metals.build-connect';
  })
end

function M.build_restart()
  M.execute_command({
    command = 'metals.build-restart';
  })
end

function M.sources_scan()
  M.execute_command({
    command = 'metals.sources-scan';
  })
end


function M.doctor_run()
  M.execute_command({
    command = 'metals.doctor-run';
  })
end

function M.compile_cascade()
  M.execute_command({
    command = 'metals.compile-cascade';
  })
end

function M.logs_toggle()
  local bufs = vim.api.nvim_list_bufs()
  for _,v in ipairs(bufs) do
    local buftype = vim.api.nvim_buf_get_option(v, 'buftype')
    if buftype == "terminal" then
      print('Logs are already opened. Try an :ls to see where it is.')
      return
    end
  end
  -- Only open them if a termianl isn't already open
  vim.api.nvim_command [[vsp term://tail -f .metals/metals.log]]
end

return M
