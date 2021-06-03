local api = vim.api
local lsp = vim.lsp

local log = require("metals.log")

local metals_packages = "metalsPackages"

local collapse_state = {
  expanded = "expanded",
  collapsed = "collapsed",
}

local function find_metals_buffer()
  local metals_buf = nil
  local bufs = api.nvim_list_bufs()

  for _, buf in pairs(bufs) do
    if api.nvim_buf_is_loaded(buf) then
      local buf_clients = lsp.buf_get_clients(buf)
      for _, client in pairs(buf_clients) do
        if client.name == "metals" then
          metals_buf = buf
          break
        end
      end
    end
  end
  if metals_buf == nil then
    log.warn_and_show("You have no buffers that Metals is attatched to. Make sure you're in a valid Scala file.")
  end
  return metals_buf
end

return {
  collapse_state = collapse_state,
  find_metals_buffer = find_metals_buffer,
  metals_packages = metals_packages,
}
