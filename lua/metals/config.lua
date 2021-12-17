local api = vim.api
local fn = vim.fn
local lsp = vim.lsp

local log = require("metals.log")
local decoration = require("metals.decoration")
local default_handlers = require("metals.handlers")
local jvmopts = require("metals.jvmopts")
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

--- Used to generate Metals installation file name depending on configuration
--- @return string fileame
local function metals_install_name()
  if config_cache and config_cache.settings.metals.useGlobalExecutable then
    return metals_name
  else
    return Path:new(util.nvim_metals_cache_dir, metals_name).filename
  end
end

--- Ultimately what will be passed to the config.cmd to initialize the LSP
--- connection. If a user is using useGlobalExecutable then we just default
--- to `metals`, if not we take control and construct the location in the
--- cache dir.
--- @return string executable
local function metals_bin()
  local metals_filename = metals_name
  -- Coursier will install both a "metals" and "metals.bat", on Windows we should use "metals.bat" as exe

  if util.is_windows then
    metals_filename = metals_name .. ".bat"
  end

  if config_cache and config_cache.settings.metals.useGlobalExecutable then
    return metals_filename
  else
    return Path:new(util.nvim_metals_cache_dir, metals_filename).filename
  end
end

--- Check to see if coursier is installed. This method favors the native cs. So if
--- cs is installed, that will be returned, if not, then coursier will be returned.
--- @return string 'cs', 'cs.bat', 'coursier', or nil
local function check_for_coursier()
  -- this must be first the second "cs" is also found as binary but we should be more specific on Windows
  if util.is_windows then
    return "cs.bat"
  else
    if util.has_bins("cs") then
      return "cs"
    elseif util.has_bins("coursier") then
      return "coursier"
    end
  end
end

local debugging_provider = false

if dap_available then
  debugging_provider = true
end

local metals_init_options = {
  compilerOptions = {},
  debuggingProvider = debugging_provider,
  decorationProvider = true,
  didFocusProvider = true,
  disableColorOutput = true,
  doctorProvider = "json",
  executeClientCommandProvider = true,
  inputBoxProvider = true,
  quickPickProvider = true,
  statusBarProvider = "show-message",
  treeViewProvider = true,
}

-- Currently available settings. These are settings used by the metals server,
-- so they are just passed along.
local valid_metals_settings = {
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
  "serverProperties",
  "showImplicitArguments",
  "showImplicitConversionsAndClasses",
  "showInferredType",
  "superMethodLensesEnabled",
}

-- We keep these seperated from the `valid_metals_settings` just for clarity.
-- The above are valide for the server, whereas these settings here are _only_
-- being used by this plugin. It's bitter sweet, as we mix settings here a bit,
-- but having multiple ways to set "settings" for metals may confuse the user
-- even more, so it's a risk I think is worth it.
local valid_nvim_metals_settings = {
  "decorationColor",
  "disabledMode",
  "serverOrg",
  "serverVersion",
  "useGlobalExecutable",
}

--- auto commands necessary for `metals/didFocusTextDocument`.
--- https://scalameta.org/metals/docs/integrations/new-editor.html#metalsdidfocustextdocument
local function auto_commands()
  api.nvim_command([[augroup NvimMetals]])
  api.nvim_command([[autocmd!]])
  api.nvim_command([[autocmd BufEnter * lua require("metals").did_focus()]])
  api.nvim_command([[augroup end]])
end

local commands = {}

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

commands["metals-run-session-start"] = debug_start_command(true)
commands["metals-debug-session-start"] = debug_start_command(false)

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
  -- NOTE! If you access anyting related to settings after this point, you need
  -- to remember you are now accessing config.setings.metals not just
  -- config.settings.
  -----------------------------------------------------------------------------

  decoration.set_color(config.settings.metals.decorationColor)
  tvp.setup_config(config.tvp or {})

  if not util.has_bins(metals_bin()) and config.settings.metals.useGlobalExecutable then
    log.error_and_show(messages.use_global_set_but_cant_find)
    return
  elseif not util.has_bins(metals_bin()) then
    local heading = "Welcome to nvim-metals!\n"

    local coursier_msg = (check_for_coursier() and "" or messages.coursier_not_installed)

    if coursier_msg ~= "" then
      log.error(coursier_msg)
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
    or { "build.sbt", "build.sc", "build.gradle", "pom.xml", ".scala", ".git" }

  local bufname = api.nvim_buf_get_name(bufnr)

  local find_root_dir = config.find_root_dir or root_dir.find_root_dir

  config.root_dir = find_root_dir(config.root_patterns, bufname) or fn.expand("%:p:h")

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

  config.cmd = util.merge_lists({ metals_bin() }, all_opts)

  -- This shouldn't really be needed as it doesn't do anything in core,
  -- however, I'm adding this in now for
  -- https://github.com/glepnir/lspsaga.nvim/issues/57 so if any users are using
  -- lspsaga it will still work as expected for the lsp_finder()
  config.filetypes = { "sbt", "scala" }

  config.on_init = function(client, _)
    return client.notify("workspace/didChangeConfiguration", { settings = config.settings })
  end

  if not config.on_attach then
    config.on_attach = auto_commands
  else
    local user_on_attach = config.on_attach
    config.on_attach = function(client, _bufnr)
      user_on_attach(client, _bufnr)
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
  validate_config = validate_config,
  valid_metals_settings = valid_metals_settings,
}
