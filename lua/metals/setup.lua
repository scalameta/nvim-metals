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

M.initialize_or_attach = function(config)
  assert(config and type(config) == 'table',
         'Your config must be a table. If you are just using the default, use {}')

  if util.has_bins('cs') then
    coursier_exe = 'cs'
  elseif util.has_bins('coursier') then
    coursier_exe = 'coursier'
  end

  assert(coursier_exe,
         'Coursier must be installed to use nvim-metals. You can find installation instruction here: https://get-coursier.io/docs/cli-installation')

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

  if (vim.g.metals_server_version) then
    server_version = vim.g.metals_server_version
  else
    server_version = 'latest.release'
  end

  -- TODO some of the stuff can probably just go into utils
  local nvim_metals_cache_dir = util.path.join{fn.stdpath("cache"), "nvim-metals"}
  local metals_bin = util.path.join{nvim_metals_cache_dir, config.name}

  if not uv.fs_stat(nvim_metals_cache_dir) then
    os.execute('mkdir -p ' .. nvim_metals_cache_dir)
  end

  local get_cmd = string.format(
                      '%s bootstrap --java-opt -Xss4m --java-opt -Xms100m org.scalameta:metals_2.12:%s -r bintray:scalacenter/releases -r sonatype:snapshots -o %s -f',
                      coursier_exe,
                      server_version,
                      metals_bin)

  vim.fn.system(get_cmd)

  config.cmd = {'metals'}

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
