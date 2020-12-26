local api = vim.api
local lsp = vim.lsp
local fn = vim.fn
local uv = vim.loop

local handlers = require 'metals.handlers'
local messages = require 'metals.messages'
local util = require 'metals.util'

local M = {}
local lsps = {}

-- Location of any files or executables that nvim-metals will create on your system
local nvim_metals_cache_dir = util.path.join {fn.stdpath('cache'), 'nvim-metals'}
-- Ultimately what will be passed to the config.cmd to initialize the LSP connection
-- TODO in the future, it might be nice to provide an alternative to this so that
-- a user _could_ just use Metals installed by cs install Metals. I'm still undecided
-- if that's wise to offer two options, or to just remain in full control like we do here
M.metals_bin = util.path.join {nvim_metals_cache_dir, 'metals'}

--[[
Check to see if coursier is installed. This method favors the native cs. So if
cs is installed, that will be returned, if not, then coursier will be returned.
--]]
local check_for_coursier = function()
  if util.has_bins('cs') then
    return 'cs'
  elseif util.has_bins('coursier') then
    return 'coursier'
  end
end

--[[
There is absolutely no difference with installing or updating, so if a user
executes `:MetalsInstall` it will just install the latest or install what they
have set no matter what. If there is an exesiting Metals there, it is simply
overwritten by the bootstrap command.
--]]
M.install_or_update = function()
  local coursier_exe = check_for_coursier()
  if not coursier_exe then
    print(messages.coursier_not_installed)
    return true
  end

  local server_version

  if (vim.g.metals_server_version) then
    server_version = vim.g.metals_server_version
  else
    server_version = 'latest.release'
  end

  if not uv.fs_stat(nvim_metals_cache_dir) then
    os.execute('mkdir -p ' .. nvim_metals_cache_dir)
  end

  local get_cmd = string.format(
                      '%s bootstrap --java-opt -Xss4m --java-opt -Xms100m org.scalameta:metals_2.12:%s -r bintray:scalacenter/releases -r sonatype:snapshots -o %s -f', -- luacheck: ignore 631
                      coursier_exe, server_version, M.metals_bin)

  vim.fn.system(get_cmd)
  if (uv.fs_stat(M.metals_bin)) then
    print(string.format(
              'Metals %s installed in %s.\n Please restart nvim, and have fun coding Scala!',
              server_version, M.metals_bin))
  end
end

--[[
The main entrypoint into the plugin. This is meant to be used in the following way:

if has('nvim-0.5')
  augroup lsp
    au!
    au FileType scala lua require('metals').initialize_or_attach(metals_config)
  augroup end
endif
--]]
M.initialize_or_attach = function(config)
  assert(config and type(config) == 'table',
         '\n\nRecieved: ' .. vim.inspect(config) .. ' as your config.\n' ..
             'Your config must be a table. If you are just using the default, just use {}')

  if not (uv.fs_stat(M.metals_bin)) then
    local heading = '\nWelcome to nvim-metals!\n'

    local courser_message = (check_for_coursier() and '' or messages.coursier_not_installed)

    print(heading .. courser_message .. messages.install_message)
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

  config.root_dir = util.find_root_dir(config.root_patterns, bufname)

  config.handlers = config.handlers or {}

  config.handlers['metals/quickPick'] = config.handlers['metals/quickPick'] or
                                            handlers['metals/quickPick']

  config.handlers['metals/inputBox'] = config.handlers['metals/inputBox'] or
                                           handlers['metals/inputBox']

  config.handlers['metals/executeClientCommand'] =
      config.handlers['metals/executeClientCommand'] or handlers['metals/executeClientCommand']

  config.handlers['textDocument/hover'] = config.handlers['textDocument/hover'] or
                                              handlers['textDocument/hover']

  config.handlers['metals/status'] = config.handlers['metals/status'] or handlers['metals/status']

  config.handlers['metals/publishDecorations'] = config.handlers['metals/publishDecorations'] or
                                                     handlers['metals/publishDecorations']

  config.handlers['window/showMessageRequest'] = config.handlers['window/showMessageRequest'] or
                                                     handlers['window/showMessageRequest']

  config.capabilities = config.capabilities or lsp.protocol.make_client_capabilities()

  config.init_options = config.init_options or {}

  -- TODO make this configurable (default probably to show-message)
  config.init_options.statusBarProvider = config.init_options.statusBarProvider or 'show-message'
  config.init_options.inputBoxProvider = config.init_options.inputBoxProvider or true
  config.init_options.quickPickProvider = config.init_options.quickPickProvider or true
  config.init_options.executeClientCommandProvider =
      config.init_options.executeClientCommandProvider or true
  config.init_options.decorationProvider = config.init_options.decorationProvider or true
  config.init_options.didFocusProvider = config.init_options.didFocusProvider or true
  config.init_options.isHttpEnabled = config.init_options.isHttpEnabled or true
  config.init_options.compilerOptions = config.init_options.compilerOptions or {}
  config.init_options.compilerOptions.snippetAutoIndent =
      config.init_options.compilerOptions.snippetAutoIndent or false

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

--[[
auto commands necessary for `metals/didFocusTextDocument`
https://scalameta.org/metals/docs/integrations/new-editor.html#metalsdidfocustextdocument
--]]
M.auto_commands = function()
  api.nvim_command [[augroup NvimMetals]]
  api.nvim_command [[autocmd BufEnter <buffer> lua require'metals'.did_focus()]]
  api.nvim_command [[augroup end]]
end

return M
