local conf = require("metals.config")
local log = require("metals.log")
local messages = require("metals.messages")
local util = require("metals.util")
local version = require("metals.version")

local Job = require("plenary.job")

-- There is absolutely no difference with installing or updating, so if a user
-- executes `:MetalsInstall` it will just install the latest or install what they
-- have set no matter what. If there is an exesiting Metals there, it is simply
-- overwritten by the bootstrap command.
-- NOTE: that if a user has g:metals_use_global_executable set, this will just
-- throw an error at them since they can't use this in that case.
-- @param sync (boolean) really only used for testing. If you are running test-setup
-- then set this to true, else just let it be.
local function install_or_update(sync)
  if vim.g.metals_use_global_executable then
    log.error_and_show(messages.use_global_set_so_cant_update)
    return true
  end

  local coursier_exe = conf.check_for_coursier()
  if not coursier_exe then
    log.error_and_show(messages.coursier_installed)
    return true
  end

  local config = conf.get_config_cache()

  local server_version = "latest.release"

  local server_org = config.settings.metals.serverOrg or vim.g.metals_server_org or "org.scalameta"

  if config.settings.metals.serverVersion then
    local desired = config.settings.metals.serverVersion
    if desired == "SNAPSHOT" and server_org ~= "org.scalameta" then
      log.warn_and_show(messages.cant_use_snapshot_setting_with_custom_org)
    elseif desired == "SNAPSHOT" then
      local latest = version.get_latest_snapshot()
      server_version = latest or server_version
    else
      server_version = desired
    end
  elseif vim.g.metals_server_version then
    log.warn_and_show(messages.server_version_setting_deprecated)
    server_version = vim.g.metals_server_version
  end

  if not util.nvim_metals_cache_dir:exists() then
    util.nvim_metals_cache_dir:mkdir()
  end

  util.metals_status("Installing Metals...")

  local args = {
    "bootstrap",
    "--java-opt",
    "-Xss4m",
    "--java-opt",
    "-Xms100m",
    string.format("%s:metals_2.12:%s", server_org, server_version),
    "-r",
    "bintray:scalacenter/releases",
    "-r",
    "sonatype:snapshots",
    "-o",
    conf.metals_bin(),
    "-f",
  }

  local job = Job:new({
    command = coursier_exe,
    args = args,
    on_exit = vim.schedule_wrap(function(_, exit)
      if exit == 0 then
        util.metals_status("Metals installed!")
        log.info_and_show("Metals installed! Start/Restart the server, and have fun coding Scala!")
      else
        log.error_and_show("Something went wrong with the Metals install. Please check the logs.")
        util.metals_status("Install failed!")
      end
    end),
    on_stdout = vim.schedule_wrap(function(err, data)
      if err then
        log.error_and_show(err)
      else
        util.metals_status(data)
      end
    end),
    on_stderr = vim.schedule_wrap(function(err, data)
      if err then
        log.error_and_show(err)
      else
        util.metals_status(data)
        log.info(data)
      end
    end),
  })
  if sync then
    job:sync()
  else
    job:start()
  end
end

return {
  install_or_update = install_or_update,
}
