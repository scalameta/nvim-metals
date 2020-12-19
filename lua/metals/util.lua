local api = vim.api
local validate = vim.validate
local uv = vim.loop

local M = {}

-- A replacement for the default `root_dir` function for metals. This is useful
-- if you have a sbt/maven/gradle build that has nested build files. The default
-- will not recognized this and instead re-initialize when you don't want it to.
M.find_root_dir = function(patterns, startpath)
  -- TODO I don't think this flatten in needed
  -- local patterns = vim.tbl_flatten {patterns}
  local function matcher(path)
    for _, pattern in ipairs(patterns) do
      local target = M.path.join(path, pattern)
      local parent_target = M.path.join(M.path.dirname(path), pattern)
      if M.path.exists(target) and not M.path.exists(parent_target) then
        return path
      end
    end
  end
  return M.search_ancestors(startpath, matcher)
end

M.search_ancestors = function(startpath, func)
  validate { func = {func, 'f'} }
  if func(startpath) then return startpath end
  for path in M.path.iterate_parents(startpath) do
    if func(path) then return path end
  end
end

-- Some path utilities
-- This is taken verbatim from nvim-lsp, but since I don't want to directly
-- require their utils module in here, it lives here for the time being.
-- https://github.com/neovim/nvim-lsp/blob/master/lua/nvim_lsp/util.lua
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

  local is_windows = uv.os_uname().version:match("Windows")
  local path_sep = is_windows and "\\" or "/"

  local is_fs_root
  if is_windows then
    is_fs_root = function(path)
      return path:match("^%a:$")
    end
  else
    is_fs_root = function(path)
      return path == "/"
    end
  end

  local dirname
  do
    local strip_dir_pat = path_sep.."([^"..path_sep.."]+)$"
    local strip_sep_pat = path_sep.."$"
    dirname = function(path)
      if not path then return end
      local result = path:gsub(strip_sep_pat, ""):gsub(strip_dir_pat, "")
      if #result == 0 then
        return "/"
      end
      return result
    end
  end

  local function path_join(...)
    local result =
      table.concat(
        vim.tbl_flatten {...}, path_sep):gsub(path_sep.."+", path_sep)
    return result
  end

  -- Traverse the path calling cb along the way.
  local function traverse_parents(path, cb)
    path = uv.fs_realpath(path)
    local dir = path
    -- Just in case our algo is buggy, don't infinite loop.
    for _ = 1, 100 do
      dir = dirname(dir)
      if not dir then return end
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
      if not v then return end
      if is_fs_root(v) then return end
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
    is_dir = is_dir;
    is_file = is_file;
    exists = exists;
    sep = path_sep;
    dirname = dirname;
    join = path_join;
    traverse_parents = traverse_parents;
    iterate_parents = iterate_parents;
    is_descendant = is_descendant;
  }
end)()

M.wrap_hover = function(bufnr, winnr)
  local hover_len = #api.nvim_buf_get_lines(bufnr,0,-1,false)[1]
  local win_width = api.nvim_win_get_width(0)
  if hover_len > win_width then
      api.nvim_win_set_width(winnr,math.min(hover_len,win_width))
      api.nvim_win_set_height(winnr,math.ceil(hover_len/win_width))
      vim.wo[winnr].wrap = true  -- luacheck: ignore 122
  end
end

---- UI. Probably this should be a separate ui.lua module if this grows.
---- CMD based UI:
M.input_box = function(prompt)
  return vim.fn.input(prompt)
end

M.input_list = function( options)
  return vim.fn.inputlist(options)
end
---------------------------------------------------------------------

-- TODO: See if nvim provides similar debugging function
M.to_string = function(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. M.to_string(v) .. ','
       end
      return s .. '} '
   else
      return tostring(o)
   end
end

return M

