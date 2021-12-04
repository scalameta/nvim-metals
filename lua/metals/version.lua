local log = require("metals.log")
local util = require("metals.util")

local Job = require("plenary.job")

local versions_ouput = {}

local get_latest_snapshot = function()
  local latest = nil

  Job
    :new({
      command = "curl",
      args = {
        "https://oss.sonatype.org/content/repositories/snapshots/org/scalameta/metals_2.12/maven-metadata.xml",
      },

      on_stdout = function(err, data)
        if not err then
          table.insert(versions_ouput, data)
        else
          log.error_and_show(
            "Something went wrong when trying to retrieve the latest SNAPSHOT. Check the logs for more info."
          )
          log.error(err)
        end
      end,
      on_exit = function(_, status)
        if status == 0 then
          for _, value in ipairs(versions_ouput) do
            local trimmed = util.full_trim(value)
            if util.starts_with(trimmed, "<version>") then
              latest = trimmed
            end
          end
          latest = latest:match(".+>(.+)<")
        end
      end,
    })
    :sync()

  return latest
end

return {
  get_latest_snapshot = get_latest_snapshot,
}
