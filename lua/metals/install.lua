local conf = require("metals.config")
local log = require("metals.log")
local messages = require("metals.messages")
local path = require("metals.path")
local status = require("metals.status")
local util = require("metals.util")

local latest_stable = "latest.stable"
local latest_snapshot = "latest.snapshot"
local the_one_true_metals = "org.scalameta"

-- The main job that actually installs Metals
-- @param coursier_exe (string) the coursier executable to be used
-- @param args (table) args to pass into the install job
-- @param sync (boolean) whether to run the job sync or async
local function do_install(coursier_exe, args, sync)
  local cmd = { coursier_exe }
  vim.list_extend(cmd, args)

  if sync then
    local result = vim.system(cmd, { timeout = 60000 }):wait()
    if result.code == 0 then
      status.set_status("Metals installed!")
      log.info_and_show("Metals installed! Start/Restart the server, and have fun coding Scala!")
    else
      log.error_and_show("Something went wrong with the Metals install. Please check the logs.")
      status.set_status("Install failed!")
    end
  else
    vim.system(cmd, {}, function(result)
      vim.schedule(function()
        if result.code == 0 then
          status.set_status("Metals installed!")
          log.info_and_show("Metals installed! Start/Restart the server, and have fun coding Scala!")
        else
          log.error_and_show("Something went wrong with the Metals install. Please check the logs.")
          status.set_status("Install failed!")
        end
      end)
    end)
  end
end

-- Puts together the args that will be passed into the actual install
-- @param server_org (string) this will default to org.scalameta, but just in case
-- @param binary_version (string) either 2.12 or 2.13 for now
-- @param version (string) the version of metals to install
-- @return a table of args for the install
local function create_args_for_install(server_org, binary_version, version)
  return {
    "bootstrap",
    "--java-opt",
    "-Xss4m",
    "--java-opt",
    "-Xms100m",
    string.format("%s:metals_%s:%s", server_org, binary_version, version),
    "-r",
    "https://central.sonatype.com/repository/maven-snapshots/",
    "-o",
    conf.metals_install_name(),
    "-f",
  }
end

-- Sort of a best attempt at actually trying to parse the server version
-- to ensure that things that are less that 0.11.3 go to 2.12 and newer
-- things go to 2.13. Snapshots and Milestones make this a bit more
-- challenging, but this should cover like 99% of the situations users
-- will hit on.
local function scala_version_for_install(server_version)
  local default = "2.13"

  if server_version == latest_stable or server_version == latest_snapshot then
    return default
  elseif vim.version.gt(vim.version.parse(server_version), vim.version.parse("0.11.2")) then
    return default
  else
    return "2.12"
  end
end

-- There is absolutely no difference with installing or updating, so if a user
-- executes `:MetalsInstall` it will just install the latest or install what they
-- have set no matter what. If there is an existing Metals there, it is then
-- overwritten by the bootstrap command.
-- NOTE: that if a user has useGlobalExecutable or metalsBinaryPath set,
-- this will just throw an error at them since they can't use this in that case.
-- @param sync (boolean) whether the run the job sync or async (mainly used for testing)
local function install_or_update(sync)
  local config = conf.get_config_cache()
  if config.settings.metals.useGlobalExecutable then
    log.error_and_show(messages.use_global_set_so_cant_update)
    return
  end

  if config.settings.metals.metalsBinaryPath then
    log.error_and_show(messages.binary_path_set_so_cant_update)
    return
  end

  local coursier_exe = conf.check_for_coursier()
  if not coursier_exe then
    log.error_and_show(messages.coursier_not_installed)
    return
  end

  if not path.exists(util.nvim_metals_cache_dir) then
    path.mkdir(util.nvim_metals_cache_dir)
  end

  local server_version = config.settings.metals.serverVersion or latest_stable

  local binary_version = scala_version_for_install(server_version)

  local server_org = config.settings.metals.serverOrg or the_one_true_metals

  status.set_status("Installing Metals...")

  if server_version == latest_snapshot and server_org == the_one_true_metals then
    status.set_status("Fetching latest snapshot version...")

    -- This is sort of a workaround to ensure that latest.snapshot works. If
    -- the user sets this we actually reach out to the metals site at
    -- latests.json to get the latest snapshot version and then do the actual
    -- install job. Coursier won't handle latest.snapshot for us or return
    -- all the snapshots if asked, so that's why we resort to this madness.
    -- https://github.com/scalameta/nvim-metals/issues/122
    local result = vim
      .system({
        "curl",
        "-s",
        "-H",
        "Accept: application/json",
        "https://scalameta.org/metals/latests.json",
      })
      :wait()

    if result.code == 0 and result.stdout then
      local ok, data = pcall(vim.fn.json_decode, result.stdout)
      if ok and data and data.snapshot then
        server_version = data.snapshot
      else
        log.error_and_show("Failed to parse latest snapshot data, defaulting to latest stable.")
        server_version = latest_stable
      end
    else
      log.error_and_show("Something went wrong getting the latest snapshot so defaulting to latest stable.")
      server_version = latest_stable
    end

    do_install(coursier_exe, create_args_for_install(server_org, binary_version, server_version), sync)
  elseif server_version == latest_snapshot then
    log.error_and_show("You must be using mainline metals to use the latest.snapshot feature")
    return
  else
    do_install(coursier_exe, create_args_for_install(server_org, binary_version, server_version), sync)
  end
end

return {
  _scala_version_for_install = scala_version_for_install,
  install_or_update = install_or_update,
}
