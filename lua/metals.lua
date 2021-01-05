local api = vim.api
local uv = vim.loop

local decoration = require 'metals.decoration'
local diagnostic = require 'metals.diagnostic'
local messages = require 'metals.messages'
local setup = require 'metals.setup'
local util = require 'metals.util'

local M = {}

-- Since we want metals to be the entrypoint for everything, just for ensure that it's
-- easy to set anything for users, we simply include them in here and then expose them.
M.bare_config = setup.bare_config
M.initialize_or_attach = setup.initialize_or_attach
M.install_or_update = setup.install_or_update
M.worksheet_hover = decoration.worksheet_hover
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

M.bsp_switch = function()
  execute_command({command = 'metals.bsp-switch'})
end

M.build_connect = function()
  execute_command({command = 'metals.build-connect'})
end

M.build_disconnect = function()
  execute_command({command = 'metals.build-disconnect'})
end

M.build_import = function()
  execute_command({command = 'metals.build-import'})
end

M.build_restart = function()
  execute_command({command = 'metals.build-restart'})
end

M.compile_cancel = function()
  execute_command({command = 'metals.compile-cancel'})
end

M.compile_cascade = function()
  execute_command({command = 'metals.compile-cascade'})
end

M.compile_clean = function()
  execute_command({command = 'metals.compile-clean'})
end

M.doctor_run = function()
  execute_command({command = 'metals.doctor-run'})
end

M.generate_bsp_config = function()
  execute_command({command = 'metals.generate-bsp-config'})
end

-- Capture info about installed Metals
M.info = function()
  if not uv.fs_stat(setup.metals_bin) then
    print(messages.metals_not_installed)
  else
    local info = util.os_capture(setup.metals_bin .. ' --version', true)
    print(info)
  end
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

-- Implements the new-scala-file feature.
-- https://scalameta.org/metals/docs/integrations/new-editor.html#create-new-scala-file
--
-- @param directory_uri_opt Path URI for the new file. e.g. 'file:///home/...'
-- @param name_opt Name for the scala file. e.g.: 'MyNewClass'. If nil, it's asked in an input box.
-- @param file_type_opt Type of file. e.g.: 'worksheet'
M.new_scala_file = function(directory_uri_opt, name_opt, file_type_opt)
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

  if file_type_opt then
    table.insert(args_string_array, 3, file_type_opt)
  else
    table.insert(args_string_array, 3, vim.NIL)
  end

  execute_command({command = 'metals.new-scala-file', arguments = args_string_array})
end

M.sources_scan = function()
  execute_command({command = 'metals.sources-scan'})
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
