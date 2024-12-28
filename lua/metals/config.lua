local api = vim.api
local fn = vim.fn
local lsp = vim.lsp

local decoration = require("metals.decoration")
local default_handlers = require("metals.handlers")
local jvmopts = require("metals.jvmopts")
local log = require("metals.log")
local messages = require("metals.messages")
local root_dir = require("metals.rootdir")
local tvp = require("metals.tvp")
local util = require("metals.util")
local Path = require("plenary.path")

local dap_available, dap = pcall(require, "dap")

local config_cache = nil

local metals_name = "metals"

local get_config_cache = function()
  return config_cache
end

local set_config_cache = function(config)
  config_cache = config
end

local scala_file_types = { "sbt", "scala" }

-- Used to check if the config table has disabledMode set. We have to do a
-- couple different checks since this is check right away when the plugin
-- is called in order to not start anything, therefore the config may not
-- be process yet meaning it doesn't exist or it's not under the metals key
-- yet.
local function in_disabled_mode(config)
  local disabled = (config.settings and config.settings.disabledMode)
    or (config.settings and config.settings.metals and config.settings.metals.disabledMode)
  return disabled
end

--- Used to generate Metals installation file
--- @return string fileame
local function metals_install_name()
  return Path:new(util.nvim_metals_cache_dir, metals_name).filename
end

--- Ultimately what will be passed to the config.cmd to initialize the LSP
--- connection. If a user is using useGlobalExecutable then we just default
--- to `metals`, if they are using metalsBinaryPath then we use that, and if
--- not we take control and construct the location in the cache dir.
--- @return string executable
local function metals_bin()
  local metals_filename = metals_name
  -- Coursier will install both a "metals" and "metals.bat", on Windows we should use "metals.bat" as exe

  if util.is_windows then
    metals_filename = metals_name .. ".bat"
  end

  if config_cache and config_cache.settings.metals.useGlobalExecutable then
    return metals_filename
  elseif config_cache and config_cache.settings.metals.metalsBinaryPath then
    return config_cache.settings.metals.metalsBinaryPath
  else
    return Path:new(util.nvim_metals_cache_dir, metals_filename).filename
  end
end

--- Check to see if coursier is installed. This method favors the native cs. So if
--- cs is installed, that will be returned, if not, then coursier will be returned.
--- @return string|nil 'cs', 'cs.bat', 'coursier', or nil
local function check_for_coursier()
  -- this must be first the second "cs" is also found as binary but we should
  -- be more specific on Windows
  if util.is_windows and util.has_bins("cs.bat") then
    return "cs.bat"
  elseif util.has_bins("cs") then
    return "cs"
  elseif util.has_bins("coursier") then
    return "coursier"
  else
    return nil
  end
end

local debugging_provider = false

if dap_available then
  debugging_provider = true
end

local metals_init_options = {
  compilerOptions = {},
  debuggingProvider = debugging_provider,
  testExplorerProvider = debugging_provider,
  decorationProvider = true,
  didFocusProvider = true,
  disableColorOutput = true,
  doctorProvider = "json",
  doctorVisibilityProvider = true,
  executeClientCommandProvider = true,
  inputBoxProvider = true,
  quickPickProvider = true,
  statusBarProvider = "show-message",
  bspStatusBarProvider = "on",
  treeViewProvider = true,
}

-- Currently available settings. These are settings used by the metals server,
-- so they are just passed along.
local valid_metals_settings = {
  "ammoniteJvmProperties",
  "autoImportBuild",
  "bloopSbtAlreadyInstalled",
  "bloopVersion",
  "bloopJvmProperties",
  "defaultBspToBuildTool",
  "enableSemanticHighlighting",
  "excludedPackages",
  "fallbackScalaVersion",
  "gradleScript",
  "inlayHints",
  "javaFormat.eclipseConfigPath",
  "javaFormat.eclipseProfile",
  "javaHome",
  "mavenScript",
  "millScript",
  "remoteLanguageServer",
  "sbtScript",
  "scalaCliLauncher",
  "scalafixConfigPath",
  "scalafixRulesDependencies",
  "scalafmtConfigPath",
  "serverProperties",
  "showImplicitArguments",
  "showImplicitConversionsAndClasses",
  "showInferredType",
  "superMethodLensesEnabled",
  "testUserInterface",
  "verboseCompilation",
}

-- We keep these separated from the `valid_metals_settings` just for clarity.
-- The above are valid for the server, whereas these settings here are _only_
-- being used by this plugin. It's bitter sweet, as we mix settings here a bit,
-- but having multiple ways to set "settings" for metals may confuse the user
-- even more, so it's a risk I think is worth it.
local valid_nvim_metals_settings = {
  "decorationColor",
  "disabledMode",
  "metalsBinaryPath",
  "serverOrg",
  "serverVersion",
  "useGlobalExecutable",
}

--- auto commands necessary for `metals/didFocusTextDocument`.
--- https://scalameta.org/metals/docs/integrations/new-editor.html#metalsdidfocustextdocument
local function auto_commands()
  api.nvim_create_autocmd("BufEnter", {
    pattern = { "*" },
    callback = function()
      require("metals").did_focus()
    end,
    group = api.nvim_create_augroup("nvim-metals-focus", { clear = true }),
  })
end

local commands = {}

-- Doesn't really fit in here, but we need to use it for the commands down below
-- and also in metals.lua, so to avoid a cyclical dep we just put it in here
local function toggle_logs()
  local bufs = api.nvim_list_bufs()

  for _, buf in ipairs(bufs) do
    local buftype = api.nvim_get_option_value("buftype", { buf = buf })
    local _, purpose = pcall(api.nvim_buf_get_var, buf, "metals_buf_purpose")
    if buftype == "terminal" and purpose == "logs" then
      local first_window_id = fn.win_findbuf(buf)[1]
      if first_window_id then
        fn.win_gotoid(first_window_id)
      else
        api.nvim_command(string.format("tabnew +buf\\ %s", buf))
      end

      return
    end
  end

  local logs_location = Path:new(config_cache.root_dir, ".metals", "metals.log")
  if logs_location:exists() then
    local cmd = [[tabnew +set\ ft=log term://tail -n 100 -f ]] .. logs_location.filename
    -- Only open them if a terminal isn't already open
    -- -n here allows for the last 100 lines to also be shown.
    -- Useful if you hit on an issue and first then toggle the logs.
    api.nvim_command(cmd)

    vim.b["metals_buf_purpose"] = "logs"
  else
    log.warn_and_show(string.format("Unable to find logs file where expected at '%s'", logs_location.filename))
  end
end

local function debug_start_command(no_debug)
  -- we are naming this from_lens since this is the only place dap will be
  -- called this way. Then we know later on by checking the name that we can
  -- simply forward on the arguments
  return function(cmd, _)
    dap.run({
      type = "scala",
      request = "launch",
      name = "from_lens",
      noDebug = no_debug,
      metals = cmd.arguments,
    })
  end
end

-- TODO if this gets to be too much duplication with the
-- metals/executeClientCommand we'll need to put these all in a table and use
-- them in both places.
commands["metals-run-session-start"] = debug_start_command(true)
commands["metals-debug-session-start"] = debug_start_command(false)
commands["metals-diagnostics-focus"] = function()
  vim.diagnostic.setqflist({ severity = "E" })
end
-- We can re-se require("metals").run_doctor which does the same thing or we'd
-- hae a cyclical dependency
commands["metals-doctor-run"] = function()
  vim.lsp.buf_request(0, "workspace/executeCommand", { command = "metals.doctor-run" })
end
commands["metals-logs-toggle"] = toggle_logs

-- Main function used to validate our config and spit out the valid one.
local function validate_config(config, bufnr)
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

  config_cache = config

  -- NOTE: This happens so early since we want to as quickly as possibly get
  -- the settings under the metals key so that other parts of the plugin that
  -- read the settings don't need to worry about where exactly the settings are.
  --
  -- We want to fall into here if it's the first time processing settings,
  -- however if the config.settings.metals exists, we know we've processed
  -- already and skip the entire thing
  if not config.settings or (config.settings and not config.settings.metals) then
    if config.settings then
      for k, _ in pairs(config.settings) do
        if not vim.tbl_contains(valid_metals_settings, k) and not (vim.tbl_contains(valid_nvim_metals_settings, k)) then
          local heading = string.format('"%s" is not a valid setting. It will be ignored.', k)
          local valid_settings = string.format(
            "The following are valid settings %s and %s",
            table.concat(valid_metals_settings, ", "),
            table.concat(valid_nvim_metals_settings, ", ")
          )
          local err = heading .. "\n" .. valid_settings
          log.warn_and_show(err)
        end
      end
    end

    local settings = { metals = {} }
    settings.metals = config.settings or {}
    config.settings = settings

    -- We special case this here since we want it on by default
    if config.settings.metals.superMethodLensesEnabled == nil then
      config.settings.metals.superMethodLensesEnabled = true
    end
  end

  -----------------------------------------------------------------------------
  -- NOTE! If you access anything related to settings after this point, you need
  -- to remember you are now accessing config.setings.metals not just
  -- config.settings.
  -----------------------------------------------------------------------------

  decoration.set_color(config.settings.metals.decorationColor)
  tvp.setup_config(config.tvp or {})

  if not util.has_bins(metals_bin()) and config.settings.metals.useGlobalExecutable then
    log.error_and_show(messages.use_global_set_but_cant_find)
    return
  elseif not util.has_bins(metals_bin()) and config.settings.metals.metalsBinaryPath then
    log.error_and_show(messages.binary_path_set_but_cant_find)
    return
  elseif not util.has_bins(metals_bin()) then
    local heading = "Welcome to nvim-metals!\n"

    local coursier_msg = ""

    if not check_for_coursier() then
      if util.is_windows then
        coursier_msg = messages.coursier_not_installed_windows
      else
        coursier_msg = messages.coursier_not_installed
      end
    end

    log.warn_and_show(heading .. coursier_msg .. messages.install_message)
    return
  end

  config.name = config.name or metals_name

  -- This is really the only not standard thing being passed into the config
  -- table, however, we'll still keep it to ensure that it's quite easy for
  -- custom patters to be passed in without doing the entire root_dir logic
  -- yourself.
  config.root_patterns = config.root_patterns
    or {
      "build.sbt",
      "build.sc",
      "build.mill",
      "build.gradle",
      "build.gradle.kts",
      "pom.xml",
      ".scala-build",
      "bleep.yaml",
      ".git",
    }

  local bufname = api.nvim_buf_get_name(bufnr)

  local find_root_dir = config.find_root_dir or root_dir.find_root_dir

  -- Maximum parent folders to search AFTER the first project file (e.g. build.sbt) was found
  local find_root_dir_max_project_nesting = config.find_root_dir_max_project_nesting or 1

  config.root_dir = find_root_dir(config.root_patterns, bufname, find_root_dir_max_project_nesting)
    or fn.expand("%:p:h")

  local base_handlers = vim.tbl_extend("error", default_handlers, tvp.handlers)

  config.handlers = util.check_exists_and_merge(base_handlers, config.handlers)

  config.commands = util.check_exists_and_merge(commands, config.commands)

  config.capabilities = util.check_exists_and_merge(lsp.protocol.make_client_capabilities(), config.capabilities)

  if not config.init_options then
    config.init_options = metals_init_options
  else
    config.init_options = vim.tbl_deep_extend("force", metals_init_options, config.init_options)
  end

  local java_opts = jvmopts.java_opts(config.root_dir)

  -- We care most about enabling options like HTTP proxy settings. We don't
  -- include memory options because Metals does not have the same memory
  -- requirements as for example the sbt build.
  local valid_java_opts = {}
  for _, opt in ipairs(java_opts) do
    if
      not util.starts_with(opt, "-Xms")
      and not util.starts_with(opt, "-Xmx")
      and not util.starts_with(opt, "-Xss")
      -- Do not alter stdout that we capture when using Coursier
      and opt ~= "-XX:+PrintCommandLineFlags"
    then
      table.insert(valid_java_opts, opt)
    end
  end

  local passed_in_options = config.settings.metals.serverProperties or {}

  local all_opts = util.merge_lists(passed_in_options, valid_java_opts)

  for i, opt in ipairs(all_opts) do
    -- In order to pass these options to coursier they need to be prefaced with `-J`
    all_opts[i] = "-J" .. opt
  end

  -- If the user overrides config.cmd then they are sort of on there on to ensure that
  -- what they are passing in can correctly start Metals. Also keep in mind that by doing
  -- this none of the metals.serverProperties will be applied and none of the java_opts
  -- from the workspce will be either. We basically have no idea what someone is overriding
  -- this with, so if they do, they are 100% on their own here.
  if not config.cmd then
    config.cmd = util.merge_lists({ metals_bin() }, all_opts)
  end

  -- This shouldn't really be needed as it doesn't do anything in core,
  -- however, I'm adding this in now for
  -- https://github.com/glepnir/lspsaga.nvim/issues/57 so if any users are using
  -- lspsaga it will still work as expected for the lsp_finder()
  config.filetypes = { "sbt", "scala" }

  if not config.on_attach then
    config.on_attach = auto_commands
  else
    local user_on_attach = config.on_attach
    config.on_attach = function(client, _bufnr)
      local ok, res = pcall(user_on_attach, client, _bufnr)
      if not ok then
        log.error_and_show(string.format("Unexpected error when evaluating user's on_attach callback: '%s'", res))
      end
      auto_commands()
    end
  end

  return config
end

return {
  check_for_coursier = check_for_coursier,
  in_disabled_mode = in_disabled_mode,
  get_config_cache = get_config_cache,
  metals_bin = metals_bin,
  metals_install_name = metals_install_name,
  metals_init_options = metals_init_options,
  scala_file_types = scala_file_types,
  set_config_cache = set_config_cache,
  toggle_logs = toggle_logs,
  validate_config = validate_config,
  valid_metals_settings = valid_metals_settings,
}
