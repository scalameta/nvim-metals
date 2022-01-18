local api = vim.api
local fn = vim.fn
local lsp = vim.lsp

local conf = require("metals.config")
local decoder = require("metals.decoder")
local decoration = require("metals.decoration")
local install = require("metals.install")
local log = require("metals.log")
local messages = require("metals.messages")
local setup = require("metals.setup")
local util = require("metals.util")

local has_plenary, Float = pcall(require, "plenary.window.float")
local _, Path = pcall(require, "plenary.path")

if not has_plenary then
  log.warn_and_show("Plenary is now required for nvim-metals. Please install nvim-lua/plenary.nvim")
end

local M = {}

-- General function used to execute various server commands.
-- @param command_params (optional, table) Parameters to send to the server (arguments and command).
-- @param callback (function) callback function for the request response.
local function execute_command(command_params, callback)
  lsp.buf_request(0, "workspace/executeCommand", command_params, function(err, result, ctx)
    if callback then
      callback(err, ctx.method, result)
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
  local config = conf.get_config_cache()
  if not util.has_bins(conf.metals_bin()) and config.settings.metals.useGlobalExecutable then
    log.error_and_show(messages.use_global_set_but_cant_find)
  elseif not util.has_bins(conf.metals_bin()) then
    log.warn_and_show(messages.metals_not_installed)
  else
    local metals_info = fn.system(conf.metals_bin() .. " --version")

    local output = {}
    for s in metals_info:gmatch("[^\r\n]+") do
      -- A little hacky but the version output is weird and we want to coerce
      -- it to markdown, so we give the verstion line a # and then strip the
      -- other lines of their #
      if util.starts_with(s, "#") then
        table.insert(output, s:sub(2))
      else
        table.insert(output, "# " .. s)
      end
    end

    if config.settings.metals then
      table.insert(output, "")
      table.insert(output, "## Current settings")
      table.insert(output, "```json")
      for s in vim.inspect(config.settings.metals):gmatch("[^\r\n]+") do
        table.insert(output, s)
      end
      table.insert(output, "```")
    end
    table.insert(output, "")
    table.insert(output, "## Useful locations")
    table.insert(output, string.format("  - nvim-metals log file: %s", log.nvim_metals_log))
    table.insert(output, string.format("  - nvim lsp log file: %s", Path:new(fn.stdpath("cache"), "lsp.log").filename))
    local loc_msg = "  - metals install location:"
    if config.settings.metals.useGlobalExecutable then
      table.insert(output, string.format("%s %s", loc_msg, "Using metals executable on $PATH"))
    else
      table.insert(output, string.format("%s %s", loc_msg, conf.metals_bin()))
    end
    table.insert(output, "")
    table.insert(output, "## Helpful links")
    table.insert(output, "  - https://gitter.im/scalameta/metals-vim")
    table.insert(output, "  - https://github.com/scalameta/nvim-metals")
    table.insert(output, "  - https://github.com/scalameta/metals")

    output = lsp.util._trim(output)

    local float = Float.percentage_range_window(0.6, 0.4, { winblend = 0 }, {
      title = "Metals Info",
      titlehighlight = "MetalsTitle",
      topleft = "┌",
      topright = "┐",
      top = "─",
      left = "│",
      right = "│",
      botleft = "└",
      botright = "┘",
      bot = "─",
    })
    -- It's seemingly impossibly to get the hl to work for me with Float, so we
    -- just manually set them here.
    api.nvim_win_set_option(float.win_id, "winhl", "NormalFloat:Normal")
    api.nvim_win_set_option(float.border_win_id, "winhl", "NormalFloat:Normal")
    api.nvim_buf_set_option(float.bufnr, "filetype", "markdown")
    api.nvim_buf_set_lines(float.bufnr, 0, -1, false, output)
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
  api.nvim_command([[vsp +set\ ft=log term://tail -f .metals/metals.log]])
  vim.b["metals_buf_purpose"] = "logs"
end

-- https://scalameta.org/metals/docs/integrations/new-editor/#create-new-scala-file
-- https://scalameta.org/metals/docs/integrations/new-editor/#create-new-java-file
--
-- @param language Either scala or java
-- @param directory_uri_opt Path URI for the new file. e.g. 'file:///home/...'
-- @param name_opt Name for the scala file. e.g.: 'MyNewClass'. If nil, it's asked in an input box.
-- @param file_type_opt Type of file. e.g.: 'worksheet'
local new_file = function(language, directory_uri_opt, name_opt, file_type_opt)
  if language ~= "scala" and language ~= "java" then
    log.warn_and_show("Unsupported language given for new file. Only scala and java are supported.")
  else
    local command = string.format("metals.new-%s-file", language)
    directory_uri_opt = directory_uri_opt or vim.NIL
    name_opt = name_opt or vim.NIL
    file_type_opt = file_type_opt or vim.NIL

    local args_string_array = {}

    table.insert(args_string_array, 1, directory_uri_opt)
    table.insert(args_string_array, 2, name_opt)
    table.insert(args_string_array, 3, file_type_opt)

    execute_command({ command = command, arguments = args_string_array })
  end
end

M.new_scala_file = function(directory_uri_opt, name_opt, file_type_opt)
  new_file("scala", directory_uri_opt, name_opt, file_type_opt)
end

M.new_java_file = function(directory_uri_opt, name_opt, file_type_opt)
  new_file("java", directory_uri_opt, name_opt, file_type_opt)
end

M.new_scala_project = function()
  execute_command({ command = "metals.new-scala-project" })
end

M.quick_worksheet = function()
  local dir = "file://" .. fn.expand("%:p:h")
  local name = fn.expand("%:p:h:t")
  M.new_scala_file(dir, name, "scala-worksheet")
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

M.find_in_dependency_jars = function()
  local function send_request(mask, query)
    lsp.buf_request(0, "metals/findTextInDependencyJars", {
      options = { include = mask },
      query = { pattern = query },
    })
  end

  local function get_query_and_send(mask)
    vim.ui.input({
      prompt = "Query: ",
    }, function(query)
      if query ~= nil then
        send_request(mask, query)
      end
    end)
  end

  vim.ui.input({
    prompt = "File mask: ",
    default = ".conf",
  }, function(mask)
    if mask ~= nil then
      get_query_and_send(mask)
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
        lsp.util.apply_workspace_edit(result.edit, "utf-16")
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
    if vim.tbl_contains(conf.scala_file_types, api.nvim_buf_get_option(buf.bufnr, "filetype")) then
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
    setup.initialize_or_attach()
  end, 3000)
end

local function show_decoded(decoder_type, format)
  local _format = ""
  if format then
    _format = "-" .. format
  end
  local file_uri = vim.uri_from_bufnr(0)
  local metals_uri = string.format("%s:%s.%s%s", decoder.metals_decode, file_uri, decoder_type, _format)
  execute_command({
    command = decoder.command,
    arguments = { metals_uri },
  }, decoder.make_handler(
    file_uri,
    decoder_type,
    format
  ))
end

M.show_tasty = function()
  show_decoded(decoder.types.tasty, decoder.formats.decoded)
end

M.show_semanticdb_compact = function()
  show_decoded(decoder.types.semanticdb, decoder.formats.compact)
end

M.show_semanticdb_detailed = function()
  show_decoded(decoder.types.semanticdb, decoder.formats.detailed)
end

M.show_semanticdb_proto = function()
  show_decoded(decoder.types.semanticdb, decoder.formats.proto)
end

M.show_cfr = function()
  show_decoded(decoder.types.cfr)
end

M.show_javap = function()
  show_decoded(decoder.types.javap)
end

M.show_javap_verbose = function()
  show_decoded(decoder.types.javap, decoder.formats.verbose)
end

M.start_server = function()
  local config = conf.get_config_cache()
  if conf.in_disabled_mode(config) then
    setup.explicitly_enable()
  end
  setup.initialize_or_attach()
end

M.goto_super_method = function()
  local text_doc_position = lsp.util.make_position_params()
  execute_command({
    command = "metals.goto-super-method",
    arguments = { text_doc_position },
  })
end

M.super_method_hierarchy = function()
  local text_doc_position = lsp.util.make_position_params()
  execute_command({
    command = "metals.super-method-hierarchy",
    arguments = { text_doc_position },
  })
end

M.type_of_range = function()
  vim.lsp.buf_request(0, "textDocument/hover", vim.lsp.util.make_given_range_params())
end

-- Since we want metals to be the entrypoint for everything, just for ensure that it's
-- easy to set anything for users, we include them in here and then expose them.
M.bare_config = setup.bare_config
M.initialize_or_attach = setup.initialize_or_attach
M.install = install.install_or_update
M.update = install.install_or_update

M.hover_worksheet = decoration.hover_worksheet

M.setup_dap = function()
  setup.setup_dap(execute_command)
end

M.toggle_setting = function(setting)
  if not vim.tbl_contains(conf.valid_metals_settings, setting) then
    log.warn_and_show(string.format("%s is not a valid metals settings. Doing nothing.", setting))
  elseif not type(setting) == "boolean" then
    log.warn_and_show(string.format("%s is not a boolean setting. You can only toggle boolean settings", setting))
  else
    local message
    local settings = conf.get_config_cache().settings.metals
    if settings[setting] == nil then
      message = string.format("Enabled %s", setting)
      settings[setting] = true
    else
      local new_setting = not settings[setting]
      message = string.format("%s is now %s", setting, new_setting)
      settings[setting] = not settings[setting]
    end
    log.info_and_show(message)

    lsp.buf_notify(0, "workspace/didChangeConfiguration", { settings = { metals = settings } })
  end
end

return M
