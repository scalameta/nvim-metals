local conf = require("metals.config")
local log = require("metals.log")
local messages = require("metals.messages")
local status = require("metals.status")
local util = require("metals.util")

local Job = require("plenary.job")

-- The main job that actually installs Metals
-- @param coursier_exe (string) the coursier executable to be used
-- @param args (table) args to pass into the install job
local function install_job(coursier_exe, args)
  local job = Job:new({
    command = coursier_exe,
    args = args,
    on_exit = vim.schedule_wrap(function(_, exit)
      if exit == 0 then
        status.set_status("Metals installed!")
        log.info_and_show("Metals installed! Start/Restart the server, and have fun coding Scala!")
      else
        log.error_and_show("Something went wrong with the Metals install. Please check the logs.")
        status.set_status("Install failed!")
      end
    end),
    on_stdout = vim.schedule_wrap(function(err, data)
      if err then
        log.error_and_show(err)
      else
        status.set_status(data)
      end
    end),
    on_stderr = vim.schedule_wrap(function(err, data)
      if err then
        log.error_and_show(err)
      else
        status.set_status(data)
        log.info(data)
      end
    end),
  })
  return job
end

-- Puts together the args that will be passed into the actual install
-- @param server_org (string) this will default to org.scalameta, but just in case
-- @param binary_version (string) either 2.12 or 2.13 for now
-- @param version (string) the version of metals to install
-- @return a table of args for the install
local function create_args_for_install(server_org, binary_version, version)
  print("creating args")
  return {
    "bootstrap",
    "--java-opt",
    "-Xss4m",
    "--java-opt",
    "-Xms100m",
    string.format("%s:metals_%s:%s", server_org, binary_version, version),
    "-r",
    "bintray:scalacenter/releases",
    "-r",
    "sonatype:snapshots",
    "-o",
    conf.metals_install_name(),
    "-f",
  }
end

-- There is absolutely no difference with installing or updating, so if a user
-- executes `:MetalsInstall` it will just install the latest or install what they
-- have set no matter what. If there is an existing Metals there, it is then
-- overwritten by the bootstrap command.
-- NOTE: that if a user has useGlobalExecutable set, this will just throw an
-- error at them since they can't use this in that case.
local function install_or_update()
  local config = conf.get_config_cache()
  if config.settings.metals.useGlobalExecutable then
    log.error_and_show(messages.use_global_set_so_cant_update)
    return
  end

  local coursier_exe = conf.check_for_coursier()
  if not coursier_exe then
    log.error_and_show(messages.coursier_installed)
    return
  end

  if not util.nvim_metals_cache_dir:exists() then
    util.nvim_metals_cache_dir:mkdir()
  end

  local latest_stable = "latest.release"
  local latest_snapshot = "latest.snapshot"
  local the_one_true_metals = "org.scalameta"
  local server_version = config.settings.metals.serverVersion or latest_stable

  local binary_version = "2.12"
  -- TODO When we release 0.11.3 we need to change this to:
  -- if server_version == latestStable or server_version > "0.11.2" then
  if server_version ~= latest_stable and server_version > "0.11.2" then
    binary_version = "2.13"
  end

  local server_org = config.settings.metals.serverOrg or the_one_true_metals

  status.set_status("Installing Metals...")

  if server_version == latest_snapshot and server_org == the_one_true_metals then
    -- This is sort of a workaround to ensure that latest.snapshot works. If
    -- the user sets this we actually reach out to the metals site at
    -- latests.json to get the latest snapshot version and then do the actual
    -- install job. Coursier won't handle latest.snapshot for us or return all the snapshots
    -- if asks, so that's why we resort to this madness.
    -- https://github.com/scalameta/nvim-metals/issues/122
    Job
      :new({
        command = "curl",
        args = {
          "-s",
          "https://scalameta.org/metals/latests.json",
        },
        on_exit = vim.schedule_wrap(function(self, job_status)
          if job_status == 0 then
            local versions = vim.fn.json_decode(table.concat(self._stdout_results, ""))
            local version = versions.snapshot or latest_stable
            install_job(coursier_exe, create_args_for_install(server_org, binary_version, version)):sync(10000)
          else
            log.error_and_show("Something went wrong getting the latest snapshot so defaulting to latest stable.")
            server_version = latest_stable
          end
        end),
      })
      :sync()
  elseif server_version == latest_snapshot then
    log.error_and_show("You must be using mainline metals to use the latest.snapshot feature")
    return
  else
    install_job(coursier_exe, create_args_for_install(server_org, binary_version, server_version)):sync(10000)
  end
end

return {
  install_or_update = install_or_update,
}
