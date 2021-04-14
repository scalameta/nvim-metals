local api = vim.api
local lsp = vim.lsp
local fn = vim.fn
local uv = vim.loop

local default_handlers = require("metals.handlers")
local log = require("metals.log")
local messages = require("metals.messages")
local util = require("metals.util")

local M = {}
local lsps = {}

local metals_name = "metals"

-- TODO I don't love having this exposed, but we need it in order to use the
-- start or restart functionality. This can probably be improved.
M.config = nil

M.scala_file_types = { "sbt", "scala" }

--- Clear out the lsps table. This is used when we are restarting the server
--- and aren't - planning on closing nvim, but rather just re-connecting.
M.reset_lsps = function()
  lsps = {}
end

--- Ultimately what will be passed to the config.cmd to initialize the LSP -
--- connection. If a user is using g:metals_use_global_executable then we - just
--- default to `metals`, if not we take control and construct the location - in
--- the cache dir.
--- @return string executable
M.metals_bin = function()
  if vim.g.metals_use_global_executable then
    return metals_name
  else
    return util.path.join(util.nvim_metals_cache_dir, metals_name)
  end
end

--
--- Check to see if coursier is installed. This method favors the native cs. So if
--- cs is installed, that will be returned, if not, then coursier will be returned.
--- @return string 'cs', 'coursier', or nil
M.check_for_coursier = function()
  if util.has_bins("cs") then
    return "cs"
  elseif util.has_bins("coursier") then
    return "coursier"
  end
end

--- There is absolutely no difference with installing or updating, so if a user
--- executes `:MetalsInstall` it will just install the latest or install what they
--- have set no matter what. If there is an exesiting Metals there, it is simply
--- overwritten by the bootstrap command.
--- NOTE: that if a user has g:metals_use_global_executable set, this will just
--- throw an error at them since they can't use this in that case.
M.install_or_update = function()
  if vim.g.metals_use_global_executable then
    log.error_and_show(messages.use_global_set_so_cant_update)
    return true
  end

  local coursier_exe = M.check_for_coursier()
  if not coursier_exe then
    log.error_and_show(messages.coursier_installed)
    return true
  end

  local server_version = vim.g.metals_server_version or "latest.release"

  if not util.path.is_dir(util.nvim_metals_cache_dir) then
    os.execute("mkdir -p " .. util.nvim_metals_cache_dir)
  end

  util.metals_status("Installing Metals...")
  local stdin = uv.new_pipe(false)
  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)

  local logOutAndError = vim.schedule_wrap(function(err, data)
    if err then
      log.error_and_show("Something went wrong with the Metals install. Please check the logs.")
      log.error(err)
    elseif data then
      if data:find("Resolution error") then
        Coursier_handle:close()
        log.error_and_show("Unable to pull something down during the Metals install. Please check the logs.")
        log.error(data)
        util.metals_status()
      else
        log.info(data)
        util.metals_status(data)
      end
    end
  end)

  local args = {
    "bootstrap",
    "--java-opt",
    "-Xss4m",
    "--java-opt",
    "-Xms100m",
    string.format("org.scalameta:metals_2.12:%s", server_version),
    "-r",
    "bintray:scalacenter/releases",
    "-r",
    "sonatype:snapshots",
    "-o",
    M.metals_bin(),
    "-f",
  }

  Coursier_handle = uv.spawn(
    M.check_for_coursier(),
    { args = args, stdio = { stdin, stdout, stderr } },
    vim.schedule_wrap(function(code)
      Coursier_handle:close()
      if (code == 0) then
        util.metals_status("Metals installed!")
        log.info_and_show("Metals installed! Start/Restart the server, and have fun coding Scala!")
      end
    end)
  )

  uv.read_start(stdout, logOutAndError)
  uv.read_start(stderr, logOutAndError)
end

-- A bare config to use to be passed into initialize_or_attach.
-- This is meant only to be used when a user is editing anything in the config
-- just to ensure they don' thave to do a couple manual initialization of tables
M.bare_config = { handlers = {}, init_options = {}, settings = {} }

local metals_init_options = {
  compilerOptions = { snippetAutoIndent = false },
  decorationProvider = true,
  didFocusProvider = true,
  disableColorOutput = true,
  doctorProvider = "json",
  executeClientCommandProvider = true,
  inputBoxProvider = true,
  quickPickProvider = true,
  statusBarProvider = "show-message",
}

-- Currently available settings.
local metals_settings = {
  "ammoniteJvmProperties",
  "bloopSbtAlreadyInstalled",
  "bloopVersion",
  "excludedPackages",
  "fallbackScalaVersion",
  "gradleScript",
  "javaHome",
  "mavenScript",
  "millScript",
  "remoteLanguageServer",
  "sbtScript",
  "scalafixConfigPath",
  "scalafmtConfigPath",
  "showImplicitArguments",
  "showImplicitConversionsAndClasses",
  "showInferredType",
}

M.add_commands = function()
  vim.cmd([[command! MetalsAmmoniteEnd lua require'metals'.ammonite_end()]])
  vim.cmd([[command! MetalsAmmoniteStart lua require'metals'.ammonite_start()]])
  vim.cmd([[command! MetalsBspSwitch lua require'metals'.bsp_switch()]])
  vim.cmd([[command! MetalsBuildConnect lua require'metals'.build_connect()]])
  vim.cmd([[command! MetalsBuildDisconnect lua require'metals'.build_disconnect()]])
  vim.cmd([[command! MetalsBuildImport lua require'metals'.build_import()]])
  vim.cmd([[command! MetalsBuildRestart lua require'metals'.build_restart()]])
  vim.cmd([[command! MetalsCompileCancel lua require'metals'.compile_cancel()]])
  vim.cmd([[command! MetalsCompileCascade lua require'metals'.compile_cascade()]])
  vim.cmd([[command! MetalsCompileClean lua require'metals'.compile_clean()]])
  vim.cmd([[command! MetalsCopyWorksheetOutput lua require'metals'.copy_worksheet_output()]])
  vim.cmd([[command! MetalsDoctor lua require'metals'.doctor_run()]])
  vim.cmd([[command! MetalsGenerateBspConfig lua require'metals'.generate_bsp_config()]])
  vim.cmd([[command! MetalsInfo lua require'metals'.info()]])
  vim.cmd([[command! MetalsInstall lua require'metals'.install_or_update()]])
  vim.cmd([[command! MetalsLogsToggle lua require'metals'.logs_toggle()]])
  vim.cmd([[command! MetalsNewScalaFile lua require'metals'.new_scala_file()]])
  vim.cmd([[command! MetalsNewScalaProject lua require'metals'.new_scala_project()]])
  vim.cmd([[command! MetalsOrganizeImports lua require'metals'.organize_imports()]])
  vim.cmd([[command! MetalsQuickWorksheet lua require'metals'.new_scala_file('file://' .. vim.fn.expand("%:p:h"), vim.fn.expand("%:p:h:t"), 'worksheet')]]) -- luacheck: ignore 631
  vim.cmd([[command! MetalsResetChoice lua require'metals'.reset_choice()]])
  vim.cmd([[command! MetalsRestartServer lua require'metals'.restart_server()]])
  vim.cmd([[command! MetalsSourcesScan lua require'metals'.sources_scan()]])
  vim.cmd([[command! MetalsStartServer lua require'metals'.start_server()]])
end

--- The main entrypoint into the plugin.
--- @param config table this config is very similiar to the config that is directly
---   passed into the `lsp.start_client(config)` with a couple exceptions.
---   1. This config doesn't make you preface the settings with `metals`. Instead
---      we just allow the user to pass in the setting and we preface the entire
---      thing.
---   2. This config has `root_patters` which are used to help determine the root_path.
M.initialize_or_attach = function(config)
  if not config or type(config) ~= "table" then
    log.error_and_show(
      "Recieved: "
        .. vim.inspect(config)
        .. " as your config.\n"
        .. "Your config must be a table.\n"
        .. "If you are just using the default, just use {}"
    )
    return
  end

  M.add_commands()
  M.config = config

  if not util.has_bins(M.metals_bin()) and vim.g.metals_use_global_executable then
    log.error_and_show(messages.use_global_set_but_cant_find)
    return true
  elseif not util.has_bins(M.metals_bin()) then
    local heading = "Welcome to nvim-metals!\n"

    local coursier_msg = (M.check_for_coursier() and "" or messages.coursier_not_installed)

    if coursier_msg ~= "" then
      log.error(coursier_msg)
    end

    log.warn_and_show(heading .. coursier_msg .. messages.install_message)
    return true
  end

  config.name = config.name or metals_name

  local bufnr = api.nvim_get_current_buf()
  local bufname = api.nvim_buf_get_name(bufnr)

  -- Check to see if Metals is already attatched, and if so attatch
  for _, buf in pairs(vim.fn.getbufinfo({ bufloaded = true })) do
    if vim.tbl_contains(M.scala_file_types, api.nvim_buf_get_option(buf.bufnr, "filetype")) then
      local clients = lsp.buf_get_clients(buf.bufnr)
      for _, client in ipairs(clients) do
        if client.config.name == config.name then
          lsp.buf_attach_client(bufnr, client.id)
          return true
        end
      end
    end
  end

  config.cmd = { M.metals_bin() }

  -- This is really the only not standard thing being passed into the config
  -- table, however, we'll still keep it to ensure that it's quite easy for
  -- custom patters to be passed in without doing the entire root_dir logic
  -- yourself.
  config.root_patterns = config.root_patterns or { "build.sbt", "build.sc", "build.gradle", "pom.xml", ".git" }

  config.root_dir = util.find_root_dir(config.root_patterns, bufname) or fn.expand("%:p:h")
  config.handlers = util.check_exists_and_merge(default_handlers, config.handlers)
  config.capabilities = util.check_exists_and_merge(lsp.protocol.make_client_capabilities(), config.capabilities)

  if not config.init_options then
    config.init_options = metals_init_options
  else
    config.init_options = vim.tbl_deep_extend("force", metals_init_options, config.init_options)
  end

  local settings = { metals = {} }

  if config.settings then
    for k, _ in pairs(config.settings) do
      if not vim.tbl_contains(metals_settings, k) then
        local heading = string.format('"%s" is not a valid setting. It will be ignored.', k)
        local valid_settings =
          string.format("The following are valid settings %s", table.concat(metals_settings, ", "))
        local err = heading .. "\n" .. valid_settings
        log.warn_and_show(err)
      end
    end
  end

  -- This shouldn't really be needed as it doesn't do anything in core,
  -- however, I'm adding this in now for
  -- https://github.com/glepnir/lspsaga.nvim/issues/57 so if any users are using
  -- lspsaga it will still work as expected for the lsp_finder()
  config.filetypes = { "sbt", "scala" }

  settings.metals = config.settings or {}
  -- Just so we can access these in the info command
  M.settings = settings.metals

  config.on_init = function(client, _)
    return client.notify("workspace/didChangeConfiguration", { settings = settings })
  end

  if not config.on_attach then
    config.on_attach = M.auto_commands
  else
    local user_on_attach = config.on_attach
    config.on_attach = function(client, _bufnr)
      user_on_attach(client, _bufnr)
      M.auto_commands()
    end
  end

  local client_id = lsps[config.root_dir]
  if not client_id then
    client_id = lsp.start_client(config)
    lsps[config.root_dir] = client_id
  end
  lsp.buf_attach_client(bufnr, client_id)
end

--- auto commands necessary for `metals/didFocusTextDocument`.
--- - https://scalameta.org/metals/docs/integrations/new-editor.html#metalsdidfocustextdocument
--- auto commands also necessary for document highlight to work.
M.auto_commands = function()
  api.nvim_command([[augroup NvimMetals]])
  api.nvim_command([[autocmd!]])
  api.nvim_command([[autocmd BufEnter <buffer> lua require'metals'.did_focus()]])
  api.nvim_command([[autocmd CursorHold  <buffer> lua vim.lsp.buf.document_highlight()]])
  api.nvim_command([[autocmd CursorMoved <buffer> lua vim.lsp.buf.clear_references()]])
  api.nvim_command([[augroup end]])
end

--- Setup function used to ensure that when using nvim-dap the
--- metals.debug-adapter-start is called and the host correctly returned.
M.setup_dap = function(execute_command)
  local status, dap = pcall(require, "dap")
  if not status then
    log.error_and_show("Unable to find nvim-dap. Please make sure mfussenegger/nvim-dap is installed.")
    return
  end

  dap.adapters.scala = function(callback, config)
    local uri = vim.uri_from_bufnr(0)
    local runType = config.metalsRunType or "run"
    execute_command({
      command = "metals.debug-adapter-start",
      arguments = { path = uri, runType = runType },
    }, function(_, _, res)
      -- In metals we throw various exceptions when hanlding
      -- debug-adapter-start but they are all handled and status messages are
      -- given to the client, so they aren't errors here. That's why we don't
      -- really capture or care about the err and instead just make sure res is
      -- there and not null.
      if res then
        local port = util.split_on(res.uri, ":")[3]

        callback({
          type = "server",
          host = "127.0.0.1",
          port = port,
          enrich_config = function(_config, on_config)
            local final_config = vim.deepcopy(_config)
            -- Just incase strip this out since it's metals-specific
            final_config.metalsRunType = nil
            on_config(final_config)
          end,
        })
      end
    end)
  end
end

return M
