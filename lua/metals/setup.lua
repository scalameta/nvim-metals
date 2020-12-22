local api = vim.api
local lsp = vim.lsp
local fn = vim.fn
local util = require 'metals.util'
local handlers = require 'metals.handlers'
local uv = vim.loop

--[[
  Facilities to help modularize the metals plugin config
--]]
local M = {}
local lsps = {}

local nvim_metals_cache_dir = util.path.join {fn.stdpath('cache'), 'nvim-metals'}
local metals_bin = util.path.join {nvim_metals_cache_dir, 'metals'}

local check_for_coursier = function()
  if util.has_bins('cs') then
    return 'cs'
  elseif util.has_bins('coursier') then
    return 'coursier'
  end
end

M.install_or_update = function()
  local coursier_exe = check_for_coursier()
  if not coursier_exe then
    print('It looks like you don\'t have coursier installed.\n' ..
              'You can find instructions on how to install it here: https://get-coursier.io/docs/cli-installation')
    return true
  end

  if (vim.g.metals_server_version) then
    server_version = vim.g.metals_server_version
  else
    server_version = 'latest.release'
  end

  if not uv.fs_stat(nvim_metals_cache_dir) then
    os.execute('mkdir -p ' .. nvim_metals_cache_dir)
  end

  local get_cmd = string.format(
                      '%s bootstrap --java-opt -Xss4m --java-opt -Xms100m org.scalameta:metals_2.12:%s -r bintray:scalacenter/releases -r sonatype:snapshots -o %s -f',
                      coursier_exe, server_version, metals_bin)

  vim.fn.system(get_cmd)
  if (uv.fs_stat(metals_bin)) then
    print(string.format('Metals %s installed in %s.\n Please restart nvim, and have fun coding Scala.',
                        server_version,
                        metals_bin))
  end
end

M.initialize_or_attach = function(config)
  assert(config and type(config) == 'table',
         '\n\nRecieved: ' .. vim.inspect(config) .. ' as your config.\n' ..
             'Your config must be a table. If you are just using the default, just use {}')

  if not (uv.fs_stat(metals_bin)) then
    local heading = '\nWelcome to nvim-metals!\n'

    local courser_message = (check_for_coursier() and '' or
                                'Before you get started, you\'ll want to make sure you have coursier installed.\n' ..
                                'You can find instructions on how to install it here: https://get-coursier.io/docs/cli-installation\n')

    local install_message = 'You\'ll need to get Metals installed before doing anything else.\n' ..
                                'You can do this using `:MetalsInstall`'

    print(heading .. courser_message .. install_message)
    return true
  end

  config.name = config.name or 'metals'

  local bufnr = api.nvim_get_current_buf()
  local bufname = api.nvim_buf_get_name(bufnr)

  -- attatch_to_active_buf
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

  config.cmd = {metals_bin}

  -- TODO change example to use a table
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

  config.capabilities = config.capabilities or lsp.protocol.make_client_capabilities()

  config.init_options = config.init_options or {}

  -- TODO make this configurable (default probably to show-message)
  config.init_options.statusBarProvider = 'on'
  config.init_options.inputBoxProvider = true
  config.init_options.quickPickProvider = true
  config.init_options.executeClientCommandProvider = true
  config.init_options.decorationProvider = true
  config.init_options.didFocusProvider = true
  config.init_options.isHttpEnabled = true
  config.init_options.compilerOptions = config.init_options.compilerOptions or {}
  config.init_options.compilerOptions.snippetAutoIndent = false

  if not config.on_attach then
    assert(1 > 2, 'yikes')
    config.on_attach = M.auto_commands
  else
    local user_on_attach = config.on_attach
    config.on_attach = function()
      user_on_attach();
      M.auto_commands();
    end
  end

  local client_id = lsps[config.root_dir]
  if not client_id then
    client_id = lsp.start_client(config)
    lsps[config.root_dir] = client_id
  end
  lsp.buf_attach_client(bufnr, client_id)
end

M.auto_commands = function()
  api.nvim_command [[augroup NvimMetals]]
  api.nvim_command [[autocmd BufEnter <buffer> lua require'metals'.did_focus()]]
  api.nvim_command [[augroup end]]
end

return M
