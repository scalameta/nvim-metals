local uv = vim.loop
local setup = require 'metals.setup'
local messages = require 'metals.messages'
local util = require 'metals.util'

local health_start = vim.fn['health#report_start']
local health_ok = vim.fn['health#report_ok']
local health_info = vim.fn['health#report_info']
local health_error = vim.fn['health#report_error']

local M = {}

M.checkHealth = function()
  health_start('Checkign env for nvim-metals')

  local os = uv.os_uname().sysname

  health_info(string.format('os: [%s]', os))
  health_info(_VERSION)

  local coursier_installed = setup.check_for_coursier()

  if coursier_installed then
    health_ok(string.format('Coursier installed and found. Will use [%s] for install.',
                            coursier_installed))
  else
    health_error(messages.coursier_not_installed)
  end

  local metals_installed = uv.fs_stat(setup.metals_bin)

  if metals_installed then
    local info = util.os_capture(setup.metals_bin .. ' --version', true)
    health_ok('Metals found')
    health_info(info)
  else
    health_error(messages.metals_not_installed)
  end

end

return M
