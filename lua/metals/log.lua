local util = require("metals.util")

local Path = require("plenary.path")

-- log.lua
--
-- Inspired by github.com/tjdevries/vlog.nvim, which was inspired by rxi/log.lua,
-- and then modified to better fit the needs of nvim-metals.
--
-- So this modules will produce the following:
--  log.info
--  log.warn
--  log.error
--
--  But also the following which I use to both log and to show the user via vim.notify.
--  log.info_and_show
--  log.warn_and_show
--  log.error_and_show
--
local M = {}

local modes = {
  info = vim.log.levels.INFO,
  warn = vim.log.levels.WARN,
  error = vim.log.levels.ERROR,
}

-- Logging utility to take x number of things to log that can be
-- strings, tables, or numbers. This will flatten them all and retrn
-- a string representation of it.
-- @param (string, number, table) as many as you wish
-- @return (string)
local make_string = function(...)
  local output = {}
  for i = 1, select("#", ...) do
    local thing_to_log = select(i, ...)

    if type(thing_to_log) == "table" then
      thing_to_log = vim.inspect(thing_to_log)
    else
      thing_to_log = tostring(thing_to_log)
    end

    output[#output + 1] = thing_to_log
  end
  return table.concat(output, " ")
end

-- Location of the nvim-metals specific log file
M.nvim_metals_log = Path:new(util.nvim_metals_cache_dir, "nvim-metals.log").filename

local generate_log_functions = function()
  if not util.nvim_metals_cache_dir:exists() then
    util.nvim_metals_cache_dir:mkdir({ parents = true })
  end
  local log_at_level = function(level, show_user, ...)
    local nameupper = level:upper()

    local msg = make_string(...)
    local info = debug.getinfo(2, "Sl")
    local lineinfo = info.short_src .. ":" .. info.currentline

    if show_user then
      local split_console = vim.split(msg, "\n")
      for _, v in ipairs(split_console) do
        vim.notify(string.format("[%s] %s", "nvim-metals", v), modes[level])
      end
    end

    local fp = io.open(M.nvim_metals_log, "a")
    local str = string.format("[%-6s%s] %s: %s\n", nameupper, os.date(), lineinfo, msg)
    fp:write(str)
    fp:close()
  end

  for key, _ in pairs(modes) do
    M[key] = function(...)
      return log_at_level(key, false, ...)
    end

    M[("%s_and_show"):format(key)] = function(...)
      return log_at_level(key, true, ...)
    end
  end
end

generate_log_functions()

return M
