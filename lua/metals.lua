local api = vim.api
local fn = vim.fn
local lsp = vim.lsp

local decoration = require("metals.decoration")
local diagnostic = require("metals.diagnostic")
local log = require("metals.log")
local messages = require("metals.messages")
local setup = require("metals.setup")
local ui = require("metals.ui")
local util = require("metals.util")

local M = {}

-- General function used to execute various server commands.
-- @param command_params (optional, table) Parameters to send to the server (arguments and command).
-- @param callback (function) callback function for the request response.
local function execute_command(command_params, callback)
  lsp.buf_request(0, "workspace/executeCommand", command_params, function(err, method, resp)
    if callback then
      callback(err, method, resp)
    elseif err then
      log.error_and_show(string.format("Could not execute command: %s", err.message))
    end
  end)
end

M.analyze_stacktrace = function()
  local trace = fn.getreg("*")
  if trace:len() > 0 then
    execute_command({ command = "metals.analyze-stacktrace", arguments = { trace } })
  else
    log.warn_and_show("No text found in your register.")
  end
end

M.start_ammonite = function()
  execute_command({ command = "metals.ammonite-start" })
end

M.stop_ammonite = function()
  execute_command({ command = "metals.ammonite-stop" })
end

M.switch_bsp = function()
  execute_command({ command = "metals.bsp-switch" })
end

M.connect_build = function()
  execute_command({ command = "metals.build-connect" })
end

M.disconnect_build = function()
  execute_command({ command = "metals.build-disconnect" })
end

M.import_build = function()
  execute_command({ command = "metals.build-import" })
end

M.restart_build = function()
  execute_command({ command = "metals.build-restart" })
end

M.compile_cancel = function()
  execute_command({ command = "metals.compile-cancel" })
end

M.compile_cascade = function()
  execute_command({ command = "metals.compile-cascade" })
end

M.compile_clean = function()
  execute_command({ command = "metals.compile-clean" })
end

M.copy_worksheet_output = function()
  local uri = vim.uri_from_bufnr(0)
  if not (string.match(uri, "worksheet.sc$")) then
    log.warn_and_show("You must be in a worksheet to use this command.")
  elseif vim.bo["modified"] then
    log.warn_and_show("Please save your worksheet before using this command.")
  else
    local copy_response = function(err, method, resp)
      if err then
        log.error_and_show(string.format("Server error with [%s]. Check logs for details.", method))
        log.error(err)
      elseif resp.value then
        fn.setreg("+", resp.value)
        log.info_and_show("Copied worksheet output to your +register")
        -- no final else needed since if there is no err and there is no val, Metals will
        -- return a warning with logMessage, so we can skip it here.
      end
    end
    execute_command({ command = "metals.copy-worksheet-output", arguments = uri }, copy_response)
  end
end

M.run_doctor = function()
  execute_command({ command = "metals.doctor-run" })
end

M.generate_bsp_config = function()
  execute_command({ command = "metals.generate-bsp-config" })
end

-- Capture info about the currently installed Metals and display it in a
-- floating window.
M.info = function()
  if not util.has_bins(setup.metals_bin()) and vim.g.metals_use_global_executable then
    log.error_and_show(messages.use_global_set_but_cant_find)
  elseif not util.has_bins(setup.metals_bin()) then
    log.warn_and_show(messages.metals_not_installed)
  else
    local metals_info = fn.system(setup.metals_bin() .. " --version")

    local output = {}
    for s in metals_info:gmatch("[^\r\n]+") do
      table.insert(output, s)
    end

    if setup.settings then
      table.insert(output, "")
      table.insert(output, "## Current settings")
      for s in vim.inspect(setup.settings):gmatch("[^\r\n]+") do
        table.insert(output, s)
      end
    end
    table.insert(output, "")
    table.insert(output, "## Useful locations")
    table.insert(output, string.format("  - nvim-metals log file: %s", log.nvim_metals_log))
    table.insert(output, string.format("  - nvim lsp log file: %s", util.path.join(fn.stdpath("cache"), "lsp.log")))
    local loc_msg = "  - metals install location:"
    if vim.g.metals_use_global_executable then
      table.insert(output, string.format("%s %s", loc_msg, "Using metals executable on $PATH"))
    else
      table.insert(output, string.format("%s %s", loc_msg, setup.metals_bin()))
    end
    table.insert(output, "")
    table.insert(output, "## Helpful links")
    table.insert(output, "  - https://gitter.im/scalameta/metals-vim")
    table.insert(output, "  - https://github.com/scalameta/nvim-metals")
    table.insert(output, "  - https://github.com/scalameta/metals")

    output = lsp.util._trim(output)
    local win_id = ui.make_float_with_borders(output, "nvim-metals")
    lsp.util.close_preview_autocmd({ "BufHidden", "BufLeave" }, win_id)
  end
end

M.toggle_logs = function()
  local bufs = api.nvim_list_bufs()

  for _, buf in ipairs(bufs) do
    local buftype = api.nvim_buf_get_option(buf, "buftype")
    local _, purpose = pcall(api.nvim_buf_get_var, buf, "metals_buf_purpose")

    if buftype == "terminal" and purpose == "logs" then
      local first_window_id = fn.win_findbuf(buf)[1]
      if first_window_id then
        fn.win_gotoid(first_window_id)
      else
        api.nvim_command(string.format("vsp | :b %i", buf))
      end

      return
    end
  end

  -- Only open them if a terminal isn't already open
  api.nvim_command([[vsp term://tail -f .metals/metals.log]])
  vim.b["metals_buf_purpose"] = "logs"
end

-- Implements the new-scala-file feature.
-- https://scalameta.org/metals/docs/integrations/new-editor/#create-new-scala-file
--
-- @param directory_uri_opt Path URI for the new file. e.g. 'file:///home/...'
-- @param name_opt Name for the scala file. e.g.: 'MyNewClass'. If nil, it's asked in an input box.
-- @param file_type_opt Type of file. e.g.: 'worksheet'
M.new_scala_file = function(directory_uri_opt, name_opt, file_type_opt)
  directory_uri_opt = directory_uri_opt or vim.NIL
  name_opt = name_opt or vim.NIL
  file_type_opt = file_type_opt or vim.NIL

  local args_string_array = {}

  table.insert(args_string_array, 1, directory_uri_opt)
  table.insert(args_string_array, 2, name_opt)
  table.insert(args_string_array, 3, file_type_opt)

  execute_command({ command = "metals.new-scala-file", arguments = args_string_array })
end

M.new_scala_project = function()
  execute_command({ command = "metals.new-scala-project" })
end

M.quick_worksheet = function()
  local dir = "file://" .. fn.expand("%:p:h")
  local name = fn.expand("%:p:h:t")
  M.new_scala_file(dir, name, "worksheet")
end

M.scan_sources = function()
  execute_command({ command = "metals.sources-scan" })
end

M.reset_choice = function()
  execute_command({ command = "metals.reset-choice" })
end

-- Notify the server when document has been focused
-- This needs to be called in the appropriate autocommand, i.e. FocusGained
M.did_focus = function()
  local focused_uri = vim.uri_from_bufnr(0)
  lsp.buf_notify(0, "metals/didFocusTextDocument", focused_uri, function(err, _, _)
    if err then
      log.error_and_show("Server error with `metals/didFocusTextDocument`. Please check your logs for details.")
      log.error(err.message)
    end
  end)
end

M.organize_imports = function()
  local params = lsp.util.make_range_params()
  params.context = { diagnostics = {}, only = { "source.organizeImports" } }
  local resp = lsp.buf_request_sync(0, "textDocument/codeAction", params, 1000)

  if not resp or vim.tbl_isempty(resp) then
    return
  end

  for _, response in pairs(resp) do
    for _, result in pairs(response.result or {}) do
      if result.edit then
        lsp.util.apply_workspace_edit(result.edit)
      else
        lsp.buf.execute_command(result.command)
      end
    end
  end
end

-- Used to fully restart Metals. This will send a shutdown request to Metals,
-- delay for 3 seconds, and then reconnect.
M.restart_server = function()
  for _, buf in pairs(fn.getbufinfo({ bufloaded = true })) do
    if vim.tbl_contains(setup.scala_file_types, api.nvim_buf_get_option(buf.bufnr, "filetype")) then
      local clients = lsp.buf_get_clients(buf.bufnr)
      for _, client in ipairs(clients) do
        if client.config.name == "metals" then
          client.stop()
        end
      end
    end
  end

  vim.defer_fn(function()
    setup.reset_lsps()
    setup.initialize_or_attach(setup.config_cache)
  end, 3000)
end

M.start_server = function()
  if vim.g.metals_disabled_mode then
    setup.explicitly_enable()
  end
  setup.initialize_or_attach(setup.config_cache)
end

M.super_method_hierarchy = function()
  local uri = vim.uri_from_bufnr(0)
  local text_doc_position = lsp.util.make_position_params()
  execute_command({
    command = "metals.super-method-hierarchy",
    arguments = { { document = uri, position = text_doc_position.position } },
  })
end

-- Since we want metals to be the entrypoint for everything, just for ensure that it's
-- easy to set anything for users, we simply include them in here and then expose them.
M.bare_config = setup.bare_config
M.initialize_or_attach = setup.initialize_or_attach
M.install = setup.install_or_update
M.update = setup.install_or_update
M.hover_worksheet = decoration.hover_worksheet
M.open_all_diagnostics = diagnostic.open_all_diagnostics
M.setup_dap = function()
  setup.setup_dap(execute_command)
end

return M
