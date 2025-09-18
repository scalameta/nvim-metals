local api = vim.api
local fn = vim.fn
local lsp = vim.lsp

local commands = require("metals.commands")
local conf = require("metals.config")
local decoder = require("metals.decoder")
local install = require("metals.install")
local log = require("metals.log")
local messages = require("metals.messages")
local path = require("metals.path")
local setup = require("metals.setup")
local test_explorer = require("metals.test_explorer")
local util = require("metals.util")
local Float = require("metals.float")

local M = {}

-- General function used to execute various server commands.
-- @param command_params (optional, table) Parameters to send to the server (arguments and command).
-- @param callback (function) callback function for the request response.
local function execute_command(command_params, callback)
  local metals_id = util.find_metals_client_id()
  local client = vim.lsp.get_client_by_id(metals_id)

  client:request("workspace/executeCommand", command_params, function(err, result, ctx)
    local response = { err = err, result = result, ctx = ctx }
    if callback then
      local context = response.ctx and response.ctx.method or ""
      callback(response.err, context, response)
    elseif response.err then
      log.error_and_show(string.format("Could not execute command: %s", response.err.message))
    end
  end)
end

M.analyze_stacktrace = function()
  local trace = fn.getreg("*")
  if trace and trace:len() > 0 then
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

M.start_scala_cli = function()
  execute_command({ command = "metals.scala-cli-start" })
end

M.stop_scala_cli = function()
  execute_command({ command = "metals.scala-cli-stop" })
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

M.restart_build_server = function()
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
      elseif resp.result.value then
        fn.setreg("+", resp.result.value)
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

-- Capture info about your Metals settings and display it in a floating window.
M.info = function()
  local config = conf.get_config_cache()
  local output = {}

  if config and config.settings.metals then
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
  table.insert(output, string.format("  - nvim lsp log file: %s", lsp.get_log_path()))
  local loc_msg = "  - metals install location:"
  if config and config.settings.metals.useGlobalExecutable then
    table.insert(output, string.format("%s %s", loc_msg, "Using metals executable on $PATH"))
  else
    table.insert(output, string.format("%s %s", loc_msg, conf.metals_bin()))
  end
  table.insert(output, "")
  table.insert(output, "## Helpful links")
  table.insert(output, "  - https://discord.gg/FaVDrJegEh")
  table.insert(output, "  - https://matrix.to/#/#scalameta:vim-users")
  table.insert(output, "  - https://github.com/scalameta/nvim-metals")
  table.insert(output, "  - https://github.com/scalameta/metals")

  output = vim.split(table.concat(output, "\n"), "\n", { trimempty = true })

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

  api.nvim_set_option_value("filetype", "markdown", { buf = float.bufnr })
  api.nvim_buf_set_lines(float.bufnr, 0, -1, false, output)
  api.nvim_buf_set_keymap(float.bufnr, "n", "q", "<cmd>close!<CR>", { nowait = true, noremap = true, silent = true })
  api.nvim_set_option_value("readonly", true, { buf = float.bufnr })
end

M.toggle_logs = conf.toggle_logs

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
  local dir = fn.expand("%:p:h")
  local name = fn.expand("%:p:h:t")
  local worksheet_path = path.join(dir, name .. ".worksheet.sc")
  if path.exists(worksheet_path) then
    local cmd = ":e" .. worksheet_path
    vim.cmd(cmd)
  else
    local dir_uri = "file://" .. dir
    M.new_scala_file(dir_uri, name, "scala-worksheet")
  end
end

M.scan_sources = function()
  execute_command({ command = "metals.sources-scan" })
end

M.reset_choice = function()
  execute_command({ command = "metals.reset-choice" })
end

M.reset_workspace = function()
  execute_command({ command = "metals.reset-workspace" })
end

-- Notify the server when document has been focused
-- This needs to be called in the appropriate autocommand, i.e. FocusGained
M.did_focus = function()
  local focused_uri = vim.uri_from_bufnr(0)
  lsp.buf_notify(0, "metals/didFocusTextDocument", focused_uri)
end

M.find_in_dependency_jars = function()
  local metals_buf = util.find_metals_buffer()

  if metals_buf then
    local function send_request(mask, query)
      lsp.buf_request(metals_buf, "metals/findTextInDependencyJars", {
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
end

M.organize_imports = function()
  local lsp_clients = lsp.get_clients({ bufnr = 0, name = "metals" })
  if not lsp_clients or vim.tbl_isempty(lsp_clients) then
    log.warn_and_show("Metals is not attatched to this buffer, so unable to organize imports.")
    return
  end
  local Metals_client = lsp_clients[1]

  local params = lsp.util.make_range_params(nil, "utf-8")
  params.context = { diagnostics = {}, only = { "source.organizeImports" } }

  local response = Metals_client:request_sync("textDocument/codeAction", params, 1000, 0)
  if not response or vim.tbl_isempty(response) then
    return
  end

  for _, result in pairs(response.result or {}) do
    if result.edit then
      lsp.util.apply_workspace_edit(result.edit, "utf-16")
    elseif result.disabled then
      log.warn_and_show(result.disabled.reason)
    else
      Metals_client:exec_cmd(result)
    end
  end
end

-- Used to fully restart Metals. This will send a shutdown request to Metals,
-- delay for 3 seconds, and then reconnect.
M.restart_metals = function()
  for _, buf in pairs(fn.getbufinfo({ bufloaded = true })) do
    if vim.tbl_contains(conf.scala_file_types, api.nvim_get_option_value("filetype", { buf = buf.bufnr })) then
      local Clients = lsp.get_clients({ buffer = buf.bufnr, name = "metals" })
      for _, Client in ipairs(Clients) do
        Client:stop()
      end
    end
  end

  vim.defer_fn(function()
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
  }, decoder.make_handler(decoder_type, format))
end

M.show_build_target_info = function()
  local choose_and_decode = function(err, method, resp)
    if err then
      log.error_and_show(string.format("Unable to retrieve build targets", method))
      log.error(err)
    elseif resp.result and not vim.tbl_isempty(resp.result) then
      vim.ui.select(resp.result, {
        prompt = "Choose build target to view:",
      }, function(choice)
        if choice ~= nil then
          local root = conf.get_config_cache().root_dir

          local metals_uri =
            string.format("%s:file:///%s/%s.%s", decoder.metals_decode, root, choice, decoder.types.build_target)
          execute_command({
            command = decoder.command,
            arguments = { metals_uri },
          }, decoder.make_handler(decoder.types.build_target))
        end
      end)
    else
      log.warn_and_show("Metals returned no info for build targets. If you're still importing, wait and try again.")
    end
  end
  execute_command({ command = "metals.list-build-targets" }, choose_and_decode)
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
  local text_doc_position = lsp.util.make_position_params(0, "utf-16")
  execute_command({
    command = "metals.goto-super-method",
    arguments = { text_doc_position },
  })
end

M.super_method_hierarchy = function()
  local text_doc_position = lsp.util.make_position_params(0, "utf-16")
  execute_command({
    command = "metals.super-method-hierarchy",
    arguments = { text_doc_position },
  })
end

M.run_scalafix = function()
  local text_doc_position = lsp.util.make_position_params(0, "utf-16")
  execute_command({ command = "metals.scalafix-run", arguments = { text_doc_position } })
end

M.run_single_scalafix = function(rules)
  local text_doc_position = lsp.util.make_position_params(0, "utf-16")
  local args = { textDocumentPositionParams = text_doc_position }
  if not rules == nil and type(rules) == "table" then
    args.rules = rules
  end

  execute_command({ command = "metals.scalafix-run-only", arguments = args })
end

M.type_of_range = function()
  local range_start = vim.fn.getpos("v")
  local range_end = vim.fn.getcurpos()

  local range_start_row = range_start[2]
  local range_start_col = range_start[3]
  local range_end_row = range_end[2]
  local range_end_col = range_end[3]

  local start_pos
  local end_pos

  if range_end_row < range_start_row or (range_start_row == range_end_row and range_start_col > range_end_col) then
    start_pos = { range_end_row, range_end_col }
    end_pos = { range_start_row, range_start_col - 1 }
  else
    start_pos = { range_start_row, range_start_col }
    end_pos = { range_end_row, range_end_col - 1 }
  end

  vim.lsp.buf_request(0, "textDocument/hover", vim.lsp.util.make_given_range_params(start_pos, end_pos, 0, "utf-16"))
end

-- Since we want metals to be the entrypoint for everything, just for ensure that it's
-- easy to set anything for users, we include them in here and then expose them.
M.bare_config = setup.bare_config
M.initialize_or_attach = setup.initialize_or_attach
M.install = install.install_or_update
M.update = install.install_or_update

-- NOTE: This whole thing is a hack. Nvim doesn't provide a nice way to get tooltips at the moment so we
-- need manually look up the inlay_hint for the current line and then display it in a floating window.
-- In order to do this, we make a couple assumptions:
-- 1. We don't call the server with resolve. Why? Because metals already sends the tooltip with the inlay hint.
--    Therefore we just skip that part and work with what we have in the inlay_hint
-- 2. We assume that the worksheet evaluation is the last inlay_hint on the line. I don't really know why
--    it wouldn't be, so we just say screw it and grab the last one.
M.hover_worksheet = function(opts)
  local buf = api.nvim_get_current_buf()
  local current_line = vim.api.nvim_win_get_cursor(0)[1] - 1
  local line_content = vim.api.nvim_buf_get_lines(0, current_line, current_line + 1, false)[1]

  -- Range for the entire line
  local range = {
    start = { line = current_line, character = 0 },
    ["end"] = { line = current_line, character = #line_content },
  }

  local line_hints = vim.lsp.inlay_hint.get({ bufnr = buf, range = range })

  -- we assume the last one is the evaluation result
  local evaluation_result = line_hints[#line_hints]

  if evaluation_result then
    local tooltip = evaluation_result.inlay_hint.tooltip

    if tooltip then
      local floating_preview_opts = util.check_exists_and_merge({ pad_left = 1, pad_right = 1 }, opts)
      lsp.util.open_floating_preview({ "```scala", tooltip, "```" }, "markdown", floating_preview_opts)
    end
  end
end

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

M.select_test_suite = function()
  local config = conf.get_config_cache()
  if config and config.settings.metals.testUserInterface == "Test Explorer" then
    test_explorer.dap_select_test_suite()
  else
    log.error_and_show(messages.enable_test_explorer)
  end
end

M.select_test_case = function()
  local config = conf.get_config_cache()
  if config and config.settings.metals.testUserInterface == "Test Explorer" then
    test_explorer.dap_select_test_case()
  else
    log.error_and_show(messages.enable_test_explorer)
  end
end

M.open_new_github_issue = function()
  execute_command({ command = "metals.open-new-github-issue" })
end

M.zip_reports = function()
  execute_command({ command = "metals.zip-reports" })
end

M.commands = function()
  vim.ui.select(commands.commands_table, {
    prompt = "Metals Commands",
    format_item = function(item)
      return item.label
    end,
  }, function(item)
    if item ~= nil then
      M[item.id]()
    end
  end)
end

return M
