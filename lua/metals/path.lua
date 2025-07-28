local M = {}

--- Join path components
---@param ... string
---@return string
M.join = function(...)
  return vim.fs.joinpath(...)
end

--- Check if file or directory exists
---@param path string
---@return boolean
M.exists = function(path)
  return vim.loop.fs_stat(path) ~= nil
end

--- Create directory with parents
---@param path string
---@param opts table|nil
---@return boolean
M.mkdir = function(path, opts)
  opts = opts or {}
  local mode = opts.parents and "p" or ""
  return vim.fn.mkdir(path, mode) == 1
end

--- Get parent directories
---@param path string
---@return table
M.parents = function(path)
  local parents = {}
  for parent in vim.fs.parents(path) do
    table.insert(parents, parent)
  end
  return parents
end

return M
