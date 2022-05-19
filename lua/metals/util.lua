local api = vim.api
local Path = require("plenary.path")

local M = {}

-- Checks to see if an executable is present for single or list of executables
-- Note that give a list, if any is not found, this will return false Also, this
-- is stolen from the nvim/nvim-lspconfig utils.
M.has_bins = function(...)
  for i = 1, select("#", ...) do
    if 0 == vim.fn.executable((select(i, ...))) then
      return false
    end
  end
  return true
end

-- Checks to see if a user given table is defined. If so, merge it with a default.
-- If not, just return the default table. This function favors the userTable on merge.
-- @param defaultTable The default table to return or merge
-- @param userTable The user defined table to check if exists and then merge
-- @return a new table that is either the default or merged with the user one.
M.check_exists_and_merge = function(defaultTable, userTable)
  -- TODO should we add another check in here to ensure that a key that a user
  -- is trying to set actually exists in the default table?
  if not userTable then
    return defaultTable
  else
    return vim.tbl_extend("force", defaultTable, userTable)
  end
end

-- Location of any files or executables that nvim-metals will create on your system
M.nvim_metals_cache_dir = function()
  return Path.new(vim.fn.stdpath("cache"), "nvim-metals")
end

--- Strip the leading and trailing spaces of a string
--- @param s string the string you want to trim.
M.full_trim = function(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

--- Strip trailing whites and trailing empty lines
--- @param s string the string you want to trim.
M.trim_end = function(s)
  return string.gsub(s, "[ \t]+%f[\r\n%z]", "")
end

M.split_on = function(s, delimiter)
  local result = {}
  local from = 1
  local delim_from, delim_to = string.find(s, delimiter, from)
  while delim_from do
    table.insert(result, string.sub(s, from, delim_from - 1))
    from = delim_to + 1
    delim_from, delim_to = string.find(s, delimiter, from)
  end
  table.insert(result, string.sub(s, from))
  return result
end

M.reverse = function(t)
  for i = 1, math.floor(#t / 2) do
    local j = #t - i + 1
    t[i], t[j] = t[j], t[i]
  end
end

M.title_case = function(first, rest)
  return first:upper() .. rest:lower()
end

M.camel_to_pascal = function(s)
  local parts = M.split_on(s, "_")
  local pascal_string = ""
  for _, part in pairs(parts) do
    local capitalized_part = string.gsub(part, "(%a)([%w_']*)", M.title_case)
    pascal_string = pascal_string .. capitalized_part
  end
  return pascal_string
end

M.merge_lists = function(a, b)
  if b == nil then
    if a == nil then
      return {}
    else
      return a
    end
  else
    local merged = vim.deepcopy(a)

    for _, v in ipairs(b) do
      if type(v) == "string" then
        table.insert(merged, v)
      end
    end

    return merged
  end
end

M.starts_with = function(text, prefix)
  return text:find(prefix, 1, true) == 1
end

M.is_windows = vim.loop.os_uname().version:match("Windows")

M.find_metals_buffer = function()
  local metals_buf = nil
  local bufs = api.nvim_list_bufs()

  for _, buf in pairs(bufs) do
    if api.nvim_buf_is_loaded(buf) then
      local buf_clients = vim.lsp.buf_get_clients(buf)
      for _, client in pairs(buf_clients) do
        if client.name == "metals" then
          metals_buf = buf
          break
        end
      end
    end
  end
  return metals_buf
end

return M
