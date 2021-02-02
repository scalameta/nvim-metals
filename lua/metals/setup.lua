local api = vim.api
local lsp = vim.lsp
local fn = vim.fn
local uv = vim.loop

local default_handlers = require 'metals.handlers'
local log = require 'metals.log'
local messages = require 'metals.messages'
local util = require 'metals.util'

local M = {}
local lsps = {}

--- Ultimately what will be passed to the config.cmd to initialize the LSP connection
--- TODO in the future, it might be nice to provide an alternative to this so that
--- a user _could_ just use Metals installed by cs install Metals. I'm still undecided
--- if that's wise to offer two options, or to just remain in full control like we do here
M.metals_bin = util.path.join(util.nvim_metals_cache_dir, 'metals')

--- Check to see if coursier is installed. This method favors the native cs. So if
--- cs is installed, that will be returned, if not, then coursier will be returned.
--- @return string 'cs', 'coursier', or nil
M.check_for_coursier = function()
  if util.has_bins('cs') then
    return 'cs'
  elseif util.has_bins('coursier') then
    return 'coursier'
  end
end

--- There is absolutely no difference with installing or updating, so if a user
--- executes `:MetalsInstall` it will just install the latest or install what they
--- have set no matter what. If there is an exesiting Metals there, it is simply
--- overwritten by the bootstrap command.
M.install_or_update = function()
  local coursier_exe = M.check_for_coursier()
  if not coursier_exe then
    log.error_and_show(messages.coursier_installed)
    return true
  end

  local server_version = vim.g.metals_server_version or 'latest.release'

  if not util.path.is_dir(util.nvim_metals_cache_dir) then
    os.execute('mkdir -p ' .. util.nvim_metals_cache_dir)
  end

  util.metals_status('Installing Metals...')
  local stdin = uv.new_pipe(false)
  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)

  local logOutAndError = vim.schedule_wrap(function(err, data)
    if err then
      log.error_and_show('Something went wrong with the Metals install. Please check the logs.')
      log.error(err)
    elseif data then
      if data:find('Resolution error') then
        Coursier_handle:close()
        log.error_and_show(
            'Unable to pull something down during the Metals install. Please check the logs.')
        log.error(data)
        util.metals_status()
      else
        log.info(data)
        util.metals_status(data)
      end
    end
  end)

  local args = {
    'bootstrap', '--java-opt', '-Xss4m', '--java-opt', '-Xms100m',
    string.format('org.scalameta:metals_2.12:%s', server_version), '-r',
    'bintray:scalacenter/releases', '-r', 'sonatype:snapshots', '-o', M.metals_bin, '-f'
  }

  Coursier_handle = uv.spawn(M.check_for_coursier(), {args = args, stdio = {stdin, stdout, stderr}},
                             vim.schedule_wrap(function(code)
    Coursier_handle:close()
    if (code == 0) then
      util.metals_status('Metals installed!')
      log.info_and_show('Metals installed! Please restart nvim, and have fun coding Scala!')
    end
  end))

  uv.read_start(stdout, logOutAndError)
  uv.read_start(stderr, logOutAndError)
end

-- A bare config to use to be passed into initialize_or_attach.
-- This is meant only to be used when a user is editing anything in the config
-- just to ensure they don' thave to do a couple manual initialization of tables
M.bare_config = {handlers = {}, init_options = {}, settings = {}}

local metals_init_options = {
  compilerOptions = {snippetAutoIndent = false},
  decorationProvider = true,
  didFocusProvider = true,
  doctorProvider = 'json',
  executeClientCommandProvider = true,
  inputBoxProvider = true,
  quickPickProvider = true,
  statusBarProvider = 'show-message'
}

-- LuaFormatter off
-- Currently available settings.
local metals_settings = {
  'ammoniteJvmProperties',
  'bloopSbtAlreadyInstalled',
  'bloopVersion',
  'excludedPackages',
  'gradleScript',
  'javaHome',
  'mavenScript',
  'millScript',
  'remoteLanguageServer',
  'sbtScript',
  'scalafixConfigPath',
  'scalafmtConfigPath',
  'showImplicitArguments',
  'showImplicitConversionsAndClasses',
  'showInferredType'
}
-- LuaFormatter on

--- The main entrypoint into the plugin.
--- @param config table this config is very similiar to the config that is directly
---   passed into the `lsp.start_client(config)` with a couple exceptions.
---   1. This config doesn't make you preface the settings with `metals`. Instead
---      we just allow the user to pass in the setting and we preface the entire
---      thing.
---   2. This config has `root_patters` which are used to help determine the root_path.
M.initialize_or_attach = function(config)

  if (not config or type(config) ~= 'table') then
    log.error_and_show('Recieved: ' .. vim.inspect(config) .. ' as your config.\n' ..
                           'Your config must be a table.\n' ..
                           'If you are just using the default, just use {}')
    return
  end

  if not (util.path.is_file(M.metals_bin)) then
    local heading = 'Welcome to nvim-metals!\n'

    local coursier_msg = (M.check_for_coursier() and '' or messages.coursier_not_installed)

    if coursier_msg ~= '' then
      log.error(coursier_msg)
    end

    log.warn_and_show(heading .. coursier_msg .. messages.install_message)
    return true
  end

  config.name = config.name or 'metals'

  local bufnr = api.nvim_get_current_buf()
  local bufname = api.nvim_buf_get_name(bufnr)

  -- Check to see if Metals is already attatched, and if so attatch
  for _, buf in pairs(vim.fn.getbufinfo({bufloaded = true})) do
    if api.nvim_buf_get_option(buf.bufnr, 'filetype') == 'scala' then
      local clients = lsp.buf_get_clients(buf.bufnr)
      for _, client in ipairs(clients) do
        if client.config.name == config.name then
          lsp.buf_attach_client(bufnr, client.id)
          return true
        end
      end
    end
  end

  config.cmd = {M.metals_bin}

  -- This is really the only not standard thing being passed into the config
  -- table, however, we'll still keep it to ensure that it's quite easy for
  -- custom patters to be passed in without doing the entire root_dir logic
  -- yourself.
  config.root_patterns = config.root_patterns or
                             {'build.sbt', 'build.sc', 'build.gradle', 'pom.xml', '.git'}

  config.root_dir = util.find_root_dir(config.root_patterns, bufname) or fn.expand('%:p:h')
  config.handlers = util.check_exists_and_merge(default_handlers, config.handlers)
  config.capabilities = util.check_exists_and_merge(lsp.protocol.make_client_capabilities(),
                                                    config.capabilities)

  if not config.init_options then
    config.init_options = metals_init_options
  else
    config.init_options = vim.tbl_deep_extend('force', metals_init_options, config.init_options)
  end

  local settings = {metals = {}}

  if config.settings then
    for k, _ in pairs(config.settings) do
      if not vim.tbl_contains(metals_settings, k) then
        local heading = string.format('"%s" is not a valid setting. It will be ignored.', k)
        local valid_settings = string.format('The following are valid settings %s',
                                             table.concat(metals_settings, ', '))
        local err = heading .. '\n' .. valid_settings
        log.warn_and_show(err)
      end
    end
  end

  -- This shouldn't really be needed as it doesn't do anything in core,
  -- however, I'm adding this in now for
  -- https://github.com/glepnir/lspsaga.nvim/issues/57 so if any users are using
  -- lspsaga it will still work as expected for the lsp_finder()
  config.filetypes = {'sbt', 'scala'}

  settings.metals = config.settings or {}
  -- Just so we can access these in the info command
  M.settings = settings.metals

  config.on_init = function(client, _)
    return client.notify('workspace/didChangeConfiguration', {settings = settings})
  end

  if not config.on_attach then
    config.on_attach = M.auto_commands
  else
    local user_on_attach = config.on_attach
    config.on_attach = function()
      user_on_attach()
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
  api.nvim_command [[augroup NvimMetals]]
  api.nvim_command [[autocmd!]]
  api.nvim_command [[autocmd BufEnter <buffer> lua require'metals'.did_focus()]]
  api.nvim_command [[autocmd CursorHold  <buffer> lua vim.lsp.buf.document_highlight()]]
  api.nvim_command [[autocmd CursorMoved <buffer> lua vim.lsp.buf.clear_references()]]
  api.nvim_command [[augroup end]]
end

return M
