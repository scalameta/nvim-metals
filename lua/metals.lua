local lsp = vim.lsp
local vim = vim
local util = require'metals.util'

local M = {}

local function execute_command(command, callback)
  vim.lsp.buf_request(0, 'workspace/executeCommand', command, function(err, _, resp)
    if callback then
      callback(err, resp)
    elseif err then
      print('Could not execute command: ' .. err.message)
    end
  end)
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
  M.execute_command({
    command = 'metals.compile-cascade';
  })
end

M.doctor_run = function()
  M.execute_command({
    command = 'metals.doctor-run';
  })
end

M.logs_toggle = function()
  local bufs = vim.api.nvim_list_bufs()
  for _,v in ipairs(bufs) do
    local buftype = vim.api.nvim_buf_get_option(v, 'buftype')
    if buftype == "terminal" then
      print('Logs are already opened. Try an :ls to see where it is.')
      return
    end
  end
  -- Only open them if a terminal isn't already open
  vim.api.nvim_command [[vsp term://tail -f .metals/metals.log]]
end

M.sources_scan = function()
  execute_command({
    command = 'metals.sources-scan';
  })
end


-- Thanks to @clason for this
-- This can be used to override the default ["textDocument/hover"]
-- in order to wrap the hover on long methods
M.hover_wrap = function(_, method, result)
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
        local hover_len = #vim.api.nvim_buf_get_lines(bufnr,0,-1,false)[1]
        local win_width = vim.api.nvim_win_get_width(0)
        if hover_len > win_width then
            vim.api.nvim_win_set_width(winnr,math.min(hover_len,win_width))
            vim.api.nvim_win_set_height(winnr,math.ceil(hover_len/win_width))
            vim.wo[winnr].wrap = true
        end
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

return M
