local api = vim.api
local fn = vim.fn
local validate = vim.validate
local uv = vim.loop

local M = {}

local search_ancestors = function(startpath, func)
  validate {func = {func, 'f'}}
  if func(startpath) then
    return startpath
  end
  for path in M.path.iterate_parents(startpath) do
    if func(path) then
      return path
    end
  end
end

-- A replacement for the default `root_dir` function that nvim-lspconfig
-- provides. This is useful if you have a sbt/maven/gradle build that has
-- nested build files. The default will not recognized this and instead
-- re-initialize when you don't want it to.
M.find_root_dir = function(patterns, startpath)
  local function matcher(path)
    for _, pattern in ipairs(patterns) do
      local target = M.path.join(path, pattern)
      local parent_target = M.path.join(M.path.dirname(path), pattern)
      if M.path.exists(target) and not M.path.exists(parent_target) then
        return path
      end
    end
  end
  return search_ancestors(startpath, matcher)
end

-- This is taken verbatim from nvim-lspconfig to help with various path utils
M.path = (function()
  local function exists(filename)
    local stat = uv.fs_stat(filename)
    return stat and stat.type or false
  end

  local function is_dir(filename)
    return exists(filename) == 'directory'
  end

  local function is_file(filename)
    return exists(filename) == 'file'
  end

  local is_windows = uv.os_uname().version:match('Windows')
  local path_sep = is_windows and '\\' or '/'

  local is_fs_root
  if is_windows then
    is_fs_root = function(path)
      return path:match('^%a:$')
    end
  else
    is_fs_root = function(path)
      return path == '/'
    end
  end

  local dirname
  do
    local strip_dir_pat = path_sep .. '([^' .. path_sep .. ']+)$'
    local strip_sep_pat = path_sep .. '$'
    dirname = function(path)
      if not path then
        return
      end
      local result = path:gsub(strip_sep_pat, ''):gsub(strip_dir_pat, '')
      if #result == 0 then
        return '/'
      end
      return result
    end
  end

  local function path_join(...)
    local result = table.concat(vim.tbl_flatten {...}, path_sep):gsub(path_sep .. '+', path_sep)
    return result
  end

  -- Traverse the path calling cb along the way.
  local function traverse_parents(path, cb)
    path = uv.fs_realpath(path)
    local dir = path
    -- Just in case our algo is buggy, don't infinite loop.
    for _ = 1, 100 do
      dir = dirname(dir)
      if not dir then
        return
      end
      -- If we can't ascend further, then stop looking.
      if cb(dir, path) then
        return dir, path
      end
      if is_fs_root(dir) then
        break
      end
    end
  end

  -- Iterate the path until we find the rootdir.
  local function iterate_parents(path)
    path = uv.fs_realpath(path)
    local function it(_, v)
      if not v then
        return
      end
      if is_fs_root(v) then
        return
      end
      return dirname(v), path
    end
    return it, path, path
  end

  local function is_descendant(root, path)
    if (not path) then
      return false;
    end

    local function cb(dir, _)
      return dir == root;
    end

    local dir, _ = traverse_parents(path, cb);

    return dir == root;
  end

  return {
    is_dir = is_dir,
    is_file = is_file,
    exists = exists,
    sep = path_sep,
    dirname = dirname,
    join = path_join,
    traverse_parents = traverse_parents,
    iterate_parents = iterate_parents,
    is_descendant = is_descendant
  }
end)()

-- Checks to see if an executable is present for single or list of executables
-- Note that give a list, if any is not found, this will return false Also, this
-- is stolen from the nvim/nvim-lspconfig utils.
M.has_bins = function(...)
  for i = 1, select('#', ...) do
    if 0 == fn.executable((select(i, ...))) then
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
  if not userTable then
    return defaultTable
  else
    return vim.tbl_extend('force', defaultTable, userTable)
  end
end

M.metals_status = function(text)
  if text then
    api.nvim_set_var('metals_status', text)
  else
    api.nvim_set_var('metals_status', '')
  end
end

-- Location of any files or executables that nvim-metals will create on your system
M.nvim_metals_cache_dir = M.path.join(fn.stdpath('cache'), 'nvim-metals')

--- Strip the leading and trailing spaces of a string
--- @param s string the string you want to trim.
M.full_trim = function(s)
  return (s:gsub('^%s*(.-)%s*$', '%1'))
end

--- Strip trailing whites and trailing empty lines
--- @param s string the string you want to trim.
M.trim_end = function(s)
    return string.gsub(s, '[ \t]+%f[\r\n%z]', '')
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

return M
