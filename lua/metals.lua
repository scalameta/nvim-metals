local api = vim.api
local decoration = require 'metals.decoration'
local diagnostic = require 'metals.diagnostic'
local setup = require 'metals.setup'

local M = {}

-- Since we want metals to be the entrypoint for everything, just for ensure that it's
-- easy to set anything for users, we simply include them in here and then expose them.
M.initialize_or_attach = setup.initialize_or_attach
M.show_hover_message = decoration.show_hover_message
M.open_all_diagnostics = diagnostic.open_all_diagnostics

-- General function used to execute various server commands.
local function execute_command(command, callback)
  vim.lsp.buf_request(0, 'workspace/executeCommand', command, function(err, method, resp)
    if callback then
      callback(err, method, resp)
    elseif err then
      print('Could not execute command: ' .. err.message)
    end
  end)
end

M.ammonite_end = function()
  execute_command({command = 'metals.ammonite-end'})
end

M.ammonite_start = function()
  execute_command({command = 'metals.ammonite-start'})
end

M.build_connect = function()
  execute_command({command = 'metals.build-connect'})
end

M.build_import = function()
  execute_command({command = 'metals.build-import'})
end

M.build_restart = function()
  execute_command({command = 'metals.build-restart'})
end

M.compile_cascade = function()
  execute_command({command = 'metals.compile-cascade'})
end

M.doctor_run = function()
  execute_command({command = 'metals.doctor-run'})
end

M.logs_toggle = function()
  local bufs = api.nvim_list_bufs()
  for _, v in ipairs(bufs) do
    local buftype = api.nvim_buf_get_option(v, 'buftype')
    if buftype == 'terminal' then
      print('Logs are already opened. Try an :ls to see where it is.')
      return
    end
  end
  -- Only open them if a terminal isn't already open
  api.nvim_command [[vsp term://tail -f .metals/metals.log]]
end

M.sources_scan = function()
  execute_command({command = 'metals.sources-scan'})
end

--[[
directory_uri_opt: Path URI for the new file. Defaults to current path. e.g. 'file:///home/...'
name_opt: Name for the scala file. e.g.: 'MyNewClass'. If nil, it's asked in an input box.
--]]
M.new_scala_file = function(directory_uri_opt, name_opt)
  local args_string_array = {}
  if directory_uri_opt then
    table.insert(args_string_array, 1, directory_uri_opt)
  else
    table.insert(args_string_array, 1, vim.NIL)
  end
  if name_opt then
    table.insert(args_string_array, 2, name_opt)
  else
    table.insert(args_string_array, 2, vim.NIL)
  end

  execute_command({command = 'metals.new-scala-file', arguments = args_string_array})
end

-- Notify the server when document has been focused
-- This needs to be called in the appropriate autocommand, i.e. FocusGained
M.did_focus = function()
  local focused_uri = vim.uri_from_bufnr(0)
  vim.lsp.buf_notify(0, 'metals/didFocusTextDocument', focused_uri, function(err, _, _)
    if err then
      print('metals/didFocusTextDocument: Server Error')
    end
  end)
end

return M
