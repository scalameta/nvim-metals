local lsp = vim.lsp
local api = vim.api
local decoration = require'metals.decoration'
local util = require'metals.util'

local M = {}

local decoration_namespace = api.nvim_create_namespace('metals_decoration');

local function execute_command(command, callback)
  vim.lsp.buf_request(0, 'workspace/executeCommand', command, function(err, method, resp)
    if callback then
      callback(err, method, resp)
    elseif err then
      print('Could not execute command: ' .. err.message)
    end
  end)
end

M.ammonite_end = function()
  execute_command({
    command = 'metals.ammonite-end'
  })
end

M.ammonite_start = function()
  execute_command({
    command = 'metals.ammonite-start'
  })
end

M.build_connect = function()
  execute_command({
    command = 'metals.build-connect';
  })
end

M.build_import = function()
   execute_command({
    command = "metals.build-import";
  })
end

M.build_restart = function()
  execute_command({
    command = 'metals.build-restart';
  })
end

M.compile_cascade = function()
  execute_command({
    command = 'metals.compile-cascade';
  })
end

M.doctor_run = function()
  execute_command({
    command = 'metals.doctor-run';
  })
end

M.logs_toggle = function()
  local bufs = api.nvim_list_bufs()
  for _,v in ipairs(bufs) do
    local buftype = api.nvim_buf_get_option(v, 'buftype')
    if buftype == "terminal" then
      print('Logs are already opened. Try an :ls to see where it is.')
      return
    end
  end
  -- Only open them if a terminal isn't already open
  api.nvim_command [[vsp term://tail -f .metals/metals.log]]
end

M.sources_scan = function()
  execute_command({
    command = 'metals.sources-scan';
  })
end

M["metals/quickPick"] = function(_, _, resp)
  local ids = {}
  local labels = {}
  for i, item in pairs(resp.items) do
    table.insert(ids, item.id)
    table.insert(labels, i .. ' - ' .. item.label )
  end

  local choice = util.input_list(labels)
  if (choice == 0) then
    print("\nmetals: operation cancelled")
    return { cancelled = true; }
  else
    return { itemId = ids[choice] }
  end
end

M['metals/inputBox'] = function(_, _, resp)
    local name = util.input_box(resp.prompt .. ': ')

    if (name == '') then
      print("\nmetals: operation cancelled")
      return { cancelled = true; }
    else
      return { value = name; }
    end
end

M['metals/executeClientCommand'] = function(_, _, cmd_request)
  if cmd_request.command == 'metals-goto-location' then
    lsp.util.jump_to_location(cmd_request.arguments[1])
  end
end

--[[
directory_uri_opt: Path URI for the new file. Defaults to current path. e.g. 'file:///home/...'
name_opt: Name for the scala file. e.g.: 'MyNewClass'. If nil, it's asked in an input box.
--]]
M.new_scala_file = function(directory_uri_opt, name_opt)
  local args_string_array = {}
  if directory_uri_opt then
    table.insert(args_string_array, 1, directory_uri_opt)
  else
    table.insert(args_string_array, 1, vim.NIL)
  end
  if name_opt then
    table.insert(args_string_array, 2, name_opt)
  else
    table.insert(args_string_array, 2, vim.NIL)
  end

  execute_command({
      command = 'metals.new-scala-file';
      arguments = args_string_array
    })
end

-- Thanks to @clason for this
-- This can be used to override the default ["textDocument/hover"]
-- in order to wrap the hover on long methods
M['textDocument/hover'] = function(_, method, result)
    local opts = {
      pad_left = 1;
      pad_right = 1;
    }
    lsp.util.focusable_float(method, function()
        if not (result and result.contents) then
            return
        end
        local markdown_lines = lsp.util.convert_input_to_markdown_lines(result.contents)
        markdown_lines = lsp.util.trim_empty_lines(markdown_lines)
        if vim.tbl_isempty(markdown_lines) then
            return
        end
        local bufnr, winnr = lsp.util.fancy_floating_markdown(markdown_lines, opts)
        lsp.util.close_preview_autocmd({"CursorMoved", "BufHidden", "InsertCharPre"}, winnr)
        util.wrap_hover(bufnr, winnr)
        return bufnr, winnr
    end)
end

-- A replacement for the default `root_dir` function for metals. This is useful
-- if you have a sbt/maven/gradle build that has nested build files. The default
-- will not recognized this and instead re-initialize when you don't want it to.
M.root_pattern = function(...)
  local patterns = vim.tbl_flatten {...}
  local function matcher(path)
    for _, pattern in ipairs(patterns) do
      local target = util.path.join(path, pattern)
      local parent_target = util.path.join(util.path.dirname(path), pattern)
      if util.path.exists(target) and not util.path.exists(parent_target) then
        return path
      end
    end
  end
  return function(startpath)
    return util.search_ancestors(startpath, matcher)
  end
end

-- Callback function to handle `metals/status`
-- This simply sets a global variable `metals_status` which can be easily
-- picked up and used in a statusline.
-- Command and Tooltip are not covered from the spec.
-- https://scalameta.org/metals/docs/editors/new-editor.html#metalsstatus
M['metals/status'] = function(_, _, params)
  if params.hide then
    api.nvim_set_var('metals_status', '')
  else
    api.nvim_set_var('metals_status', params.text)
  end
end

M['metals/publishDecorations'] = function(err, _, decorations)
  if err then
    print("metals.publishDecorations: Server error")
  end
  if not decorations then
    return
  end

  local uri = decorations.uri
  local bufnr = vim.uri_to_bufnr(uri)
  if not bufnr then
    print("metals.publishDecorations: Couldn't find buffer for ", uri)
    return
  end

  -- Unloaded buffers should not handle diagnostics.
  -- When the buffer is loaded, we'll call on_attach, which sends textDocument/didOpen.
  if not api.nvim_buf_is_loaded(bufnr) then
    return
  end

  local decoration_color = vim.g.metals_decoration_color

  api.nvim_buf_clear_namespace(bufnr, decoration_namespace, 0, -1)
  decoration.clear_hover_messages()

  for _, deco in ipairs(decorations.options) do
    decoration.set_decoration(bufnr, decoration_namespace, deco, decoration_color)
    decoration.store_hover_message(deco)
  end
end

-- Notify the server when document has been focused
-- This needs to be called in the appropriate autocommand, i.e. FocusGained
M.did_focus = function()
  local focused_uri = vim.uri_from_bufnr(0)
  vim.lsp.buf_notify(0, 'metals/didFocusTextDocument', focused_uri, function(err, _, _)
    if err then
      print('metals/didFocusTextDocument: Server Error')
    end
  end)
end

return M
