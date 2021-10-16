local api = vim.api
local fn = vim.fn
local lsp = vim.lsp

local log = require("metals.log")
local default_handlers = require("metals.handlers")
local jvmopts = require("metals.jvmopts")
local messages = require("metals.messages")
local tvp = require("metals.tvp")
local util = require("metals.util")

local config_cache = nil

local metals_name = "metals"

local get_config_cache = function()
  return config_cache
end

local scala_file_types = { "sbt", "scala" }
--- Ultimately what will be passed to the config.cmd to initialize the LSP -
--- connection. If a user is using g:metals_use_global_executable then we - just
--- default to `metals`, if not we take control and construct the location - in
--- the cache dir.
--- @return string executable
local function metals_bin()
  if vim.g.metals_use_global_executable then
    return metals_name
  else
    return util.path.join(util.nvim_metals_cache_dir, metals_name)
  end
end

--- Check to see if coursier is installed. This method favors the native cs. So if
--- cs is installed, that will be returned, if not, then coursier will be returned.
--- @return string 'cs', 'coursier', or nil
local function check_for_coursier()
  if util.has_bins("cs") then
    return "cs"
  elseif util.has_bins("coursier") then
    return "coursier"
  end
end

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
  treeViewProvider = true,
}

-- Currently available settings.
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

--- auto commands necessary for `metals/didFocusTextDocument`.
--- https://scalameta.org/metals/docs/integrations/new-editor.html#metalsdidfocustextdocument
local function auto_commands()
  api.nvim_command([[augroup NvimMetals]])
  api.nvim_command([[autocmd!]])
  api.nvim_command([[autocmd BufEnter * lua require("metals").did_focus()]])
  api.nvim_command([[augroup end]])
end

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

  tvp.setup_config(config.tvp or {})

  if not util.has_bins(metals_bin()) and vim.g.metals_use_global_executable then
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
  config.root_patterns = config.root_patterns or { "build.sbt", "build.sc", "build.gradle", "pom.xml", ".git" }

  local bufname = api.nvim_buf_get_name(bufnr)

  config.root_dir = util.find_root_dir(config.root_patterns, bufname) or fn.expand("%:p:h")

  local base_handlers = vim.tbl_extend("error", default_handlers, tvp.handlers)

  config.handlers = util.check_exists_and_merge(base_handlers, config.handlers)

  config.capabilities = util.check_exists_and_merge(lsp.protocol.make_client_capabilities(), config.capabilities)

  if not config.init_options then
    config.init_options = metals_init_options
  else
    config.init_options = vim.tbl_deep_extend("force", metals_init_options, config.init_options)
  end

  -- We want to fall into here if it's the first time processing settings,
  -- however if the config.settings.metals exists, we know we've processed
  -- already and skip the entire thing
  if not config.settings or (config.settings and not config.settings.metals) then
    if config.settings then
      for k, _ in pairs(config.settings) do
        if not vim.tbl_contains(valid_metals_settings, k) then
          local heading = string.format('"%s" is not a valid setting. It will be ignored.', k)
          local valid_settings = string.format(
            "The following are valid settings %s",
            table.concat(valid_metals_settings, ", ")
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
  get_config_cache = get_config_cache,
  metals_bin = metals_bin,
  metals_init_options = metals_init_options,
  scala_file_types = scala_file_types,
  validate_config = validate_config,
  valid_metals_settings = valid_metals_settings,
}
