local api = vim.api
local fn = vim.fn

local log = require("metals.log")
local util = require("metals.util")
local Path = require("plenary.path")

local formats = {
  compact = "compact",
  decoded = "decoded",
  detailed = "detailed",
  proto = "proto",
  verbose = "verbose",
}

local types = {
  build_target = "metals-buildtarget",
  cfr = "cfr",
  javap = "javap",
  semanticdb = "semanticdb",
  tasty = "tasty",
}

local function filename_from_uri(full_uri)
  local parts = util.split_on(full_uri, "/")
  return parts[#parts]
end

local handle_decoder_response = function(result, decoder, format)
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
    local filename = filename_from_uri(result.requestedUri)
    local name = string.format("%s %s %s viewer", filename, format or "", decoder)
    local cwd = fn.getcwd()

    local exists = nil

    local bufs = api.nvim_list_bufs()

    for _, buf in pairs(bufs) do
      local bufname = api.nvim_buf_get_name(buf)
      local joined = Path:new(cwd, name).filename
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
      if decoder == types.javap then
        api.nvim_buf_set_option(new_buffer, "syntax", "java")
      elseif decoder == types.build_target then
        api.nvim_buf_set_option(new_buffer, "syntax", "txt")
      else
        api.nvim_buf_set_option(new_buffer, "syntax", "scala")
      end
      api.nvim_win_set_buf(0, new_buffer)
    end
  end
  -- Don't worry about the final else here, it's the situation where the user
  -- cancells the quickpick so we only return the uri, not result, no err.
end

local make_handler = function(decoder, format)
  return function(err, _, result)
    if err then
      log.error_and_show(string.format("Something went wrong trying to get %s. Please check the logs.", decoder))
      log.error(err)
    else
      handle_decoder_response(result, decoder, format)
    end
  end
end

return {
  command = "metals.file-decode",
  formats = formats,
  make_handler = make_handler,
  metals_decode = "metalsDecode",
  types = types,
}
