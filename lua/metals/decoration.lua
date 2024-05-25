local api = vim.api
local log = require("metals.log")
local util = require("metals.util")
local lsp = require("vim.lsp")

local hover_messages = {}
local hover_color = "Conceal"

local M = {}

M.decoration_namespace = function()
  return api.nvim_create_namespace("metals_decoration")
end

M.set_decoration = function(bufnr, decoration)
  local line = decoration.range["end"].line
  local text = decoration.renderOptions.after.contentText
  local virt_texts = {}
  table.insert(virt_texts, { text, hover_color })

  local virt_text_opts = { virt_text = virt_texts, hl_mode = "combine" }
  local ext_id = api.nvim_buf_set_extmark(bufnr, M.decoration_namespace(), line, -1, virt_text_opts)

  if decoration.hoverMessage then
    local hover_message = lsp.util.convert_input_to_markdown_lines(decoration.hoverMessage, {})
    hover_message = vim.split(table.concat(hover_message, "\n"), "\n", { trimempty = true })

    hover_messages[ext_id] = hover_message
  end
end

M.hover_worksheet = function(opts)
  local buf = api.nvim_get_current_buf()
  local line, _ = unpack(api.nvim_win_get_cursor(0))

  local exists, ext_ids = pcall(
    api.nvim_buf_get_extmarks,
    buf,
    M.decoration_namespace(),
    { line - 1, 0 },
    { line - 1, -1 },
    { details = true }
  )

  if not exists then
    return
    -- In reality extmarks can have x amount extmarks in any given position,
    -- but with worksheets it's only logical to have an extmark one per line
    -- (after evaluation). So we double check this. If this does happen, then
    -- I've done something wrong with my logic here.
  elseif #ext_ids > 1 then
    log.error_and_show(
      "Recieved two extmarks on a single line. This should never happen with worksheets. Please create a nvim-metals issue."
    )
    return
  elseif #ext_ids == 1 then
    -- We only want the extmark_id which is in pos 1
    local id = ext_ids[1][1]

    local hover_message = hover_messages[id]

    -- This also shuoldn't happen but to avoid an empty window we do a sanity check
    if hover_message == nil then
      return
    end

    local floating_preview_opts = util.check_exists_and_merge({ pad_left = 1, pad_right = 1 }, opts)
    lsp.util.open_floating_preview(hover_message, "markdown", floating_preview_opts)
  end
end

-- Clears both the hover messages in the hover_messages table but also the
-- extmarks in the decoration namespace.
M.clear = function(bufnr)
  api.nvim_buf_clear_namespace(bufnr, M.decoration_namespace(), 0, -1)
  hover_messages = {}
end

-- Little weird to have this, but if we include config in here to pull the
-- config cache we end up with a cyclical dependency. So instead in config we
-- just call this setup.
M.set_color = function(color)
  if color then
    hover_color = color
  end
end

return M
