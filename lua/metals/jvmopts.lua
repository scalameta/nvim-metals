-- This file is taken from:
-- https://github.com/ckipp01/nvim-jvmopts
-- While there is a little but of duplication in here with other parts of the
-- codebase, I'd rather just leave it fully intact since this is all tested in
-- that repo.

local uv = vim.loop

local is_windows = uv.os_uname().version:match("Windows")
local path_sep = is_windows and "\\" or "/"

local function path_join(...)
  local result = table.concat(vim.tbl_flatten({ ... }), path_sep):gsub(path_sep .. "+", path_sep)
  return result
end

local function exists(filename)
  local stat = uv.fs_stat(filename)
  return stat and stat.type or false
end

local function trim(s)
  return s:match("^%s*(.-)%s*$")
end

local function clean(lines)
  local cleaned = {}

  for _, var in ipairs(lines) do
    table.insert(cleaned, trim(var))
  end

  return cleaned
end

local function merge_lists(a, b)
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

local function parse_env_variable(variable)
  local options = {}
  if variable == nil then
    return options
  else
    for substring in variable:gmatch("%S+") do
      table.insert(options, substring)
    end
    return options
  end
end

local function read_from_file(file)
  if exists(file) then
    local lines = {}
    for line in io.lines(file) do
      lines[#lines + 1] = line
    end
    return lines
  else
    return {}
  end
end

local function java_opts_from_env()
  return clean(parse_env_variable(os.getenv("JAVA_OPTS")))
end

local function java_flags_from_env()
  return clean(parse_env_variable(os.getenv("JAVA_FLAGS")))
end

local function java_env()
  return merge_lists(java_opts_from_env(), java_flags_from_env())
end

local function java_opts_from_file(workspace_root)
  if workspace_root ~= nil then
    local jvm_opts_file = path_join(workspace_root, ".jvmopts")
    return clean(read_from_file(jvm_opts_file))
  else
    return {}
  end
end

local function java_opts(workspace)
  return merge_lists(java_env(), java_opts_from_file(workspace))
end

return {
  java_env = java_env,
  java_flags_from_env = java_flags_from_env,
  java_opts = java_opts,
  java_opts_from_env = java_opts_from_env,
  java_opts_from_file = java_opts_from_file,
}
