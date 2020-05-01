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


--[[ Need to add some more stuff in before enabling this
function M.doctor_run()
  M.execute_command({
    command = 'metals.doctor-run';
  })
end
--]]

function M.compile_cascade()
  M.execute_command({
    command = 'metals.compile-cascade';
  })
end

--[[ TODO: How do I send a shutdown request? ]]

return M
