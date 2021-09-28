local api = vim.api
local fn = vim.fn

local log = require("metals.log")
local util = require("metals.util")

local function filename_from_uri(full_uri)
  local parts = util.split_on(full_uri, "/")
  return parts[#parts]
end

local handle_decoder_response = function(result, uri, decoder, format)
  -- NOTE: Sort of a temporary hack until this gets fixed. I
  -- often get "Error: class not found" returned as a valid
  -- result. Since that's not, we capture it and error on it.
  if result.error or util.starts_with(result.value, "Error: class not found:") then
    local err = result.err or result.value
    log.error_and_show(err)
  else
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
  javap = "javap",
  handle_decoder_response = handle_decoder_response,
  make_handler = make_handler,
  metals_decode = "metalsDecode:",
  semanticdb = "semanticdb",
}
