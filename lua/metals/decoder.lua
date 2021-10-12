local api = vim.api
local fn = vim.fn

local log = require("metals.log")
local util = require("metals.util")

local function filename_from_uri(full_uri)
  local parts = util.split_on(full_uri, "/")
  return parts[#parts]
end

local handle_decoder_response = function(result, uri, decoder, format)
  if result.error then
    local err = result.error or result.value
    log.error_and_show(err)
  elseif result.value and util.starts_with(result.value, "Error: class not found:") then
    log.error(
      string.format(
        "It looks like we are still having issues finding classes. Happened while trying to find it for: %s",
        result.requestedUri
      )
    )
    log.error_and_show("This shouldn't happen. Please check the logs and report a bug that you saw this.")
  elseif result.value then
    local filename = filename_from_uri(uri)
    local name = string.format("%s %s %s viewer", filename, format or "", decoder)
    local cwd = fn.getcwd()

    local exists = nil

    local bufs = api.nvim_list_bufs()

    for _, buf in pairs(bufs) do
      local bufname = api.nvim_buf_get_name(buf)
      local joined = util.path.join(cwd, name)
      if bufname == joined and api.nvim_buf_is_loaded(buf) then
        exists = buf
        break
      end
    end

    local returned_value = result.value
    local lines = util.split_on(returned_value, "\n")

    if exists then
      api.nvim_buf_set_lines(exists, 0, -1, false, lines)
      api.nvim_win_set_buf(0, exists)
    else
      local new_buffer = api.nvim_create_buf(true, true)
      api.nvim_buf_set_lines(new_buffer, 0, -1, false, lines)
      api.nvim_buf_set_name(new_buffer, name)
      -- TODO we should probably do something better for this case, but java is
      -- a bit nicer syntax for these than scala
      if decoder == "javap" then
        api.nvim_buf_set_option(new_buffer, "syntax", "java")
      else
        api.nvim_buf_set_option(new_buffer, "syntax", "scala")
      end
      api.nvim_win_set_buf(0, new_buffer)
    end
  end
  -- Don't worry about the final else here, it's the situation where the user
  -- cancells the quickpick so we only return the uri, not result, no err.
end

local make_handler = function(uri, decoder, format)
  return function(err, _, result)
    if err then
      log.error_and_show(string.format("Something went wrong trying to get %s. Please check the logs.", decoder))
      log.error(err)
    else
      handle_decoder_response(result, uri, decoder, format)
    end
  end
end

return {
  command = "metals.file-decode",
  formats = {
    compact = "compact",
    decoded = "decoded",
    detailed = "detailed",
    proto = "proto",
    verbose = "verbose",
  },
  handle_decoder_response = handle_decoder_response,
  make_handler = make_handler,
  metals_decode = "metalsDecode",
  types = {
    javap = "javap",
    semanticdb = "semanticdb",
    tasty = "tasty",
  },
}
