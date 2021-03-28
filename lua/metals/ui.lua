local api = vim.api
local util = require("metals.util")

local M = {}

--- @param line string
local function pad(line)
  return " " .. line .. " "
end

--- @param item string
--- @param width number
--- @param char string
--- @return string
local function insert_float_title(item, width, char)
  item = pad(item)
  local remainder = width - item:len()
  item = item .. string.rep(char, remainder - 2)
  return item
end

--- @param item string
--- @param position string 'mid' | 'bottom' | 'top'
local function add_border(item, position)
  if position == "top" then
    return "╭" .. item .. "╮"
  elseif position == "mid" then
    return "│" .. item .. "│"
  elseif position == "bottom" then
    return "╰" .. item .. "╯"
  end
end

--- @param buf number
--- @param title string
local function highlight_title(buf, title)
  if not title then
    return
  end
  local start_col = 4
  api.nvim_buf_add_highlight(
    buf,
    -1, -- Namespace ID
    "Title", -- Highlight group
    0, -- line number
    start_col, -- start
    start_col + title:len() -- end
  )
end

---Get basic configuration to give to nvim_open_win()
---@param width number
---@param height number
---@return table
local function get_window_config(width, height, win_id)
  local win_width = api.nvim_win_get_width(win_id)
  local row = math.floor((vim.o.lines * 0.5 - vim.o.cmdheight - 1) / 2)
  local col = math.floor((win_width - width) / 2)
  return {
    relative = "win",
    width = width,
    height = height,
    col = col,
    row = row,
    style = "minimal",
    focusable = false,
  }
end

--- Given a bunch of lines to be displayed in a float, ensure that it doesn't
--- exceed a given width. If the line does, break it by sentence.
--- @param lines table
--- @param max_length number
--- @return table {output = table, longest = number}
local function enforce_width(lines, max_length)
  local output = {}
  local longest = 0

  for _, line in ipairs(lines) do
    if line:len() > max_length then
      local splits = util.split_on(line, "%.")
      for _, split_line in ipairs(splits) do
        local trimmed_line = util.full_trim(split_line)
        if trimmed_line ~= "" then
          local full_line = trimmed_line .. "."
          table.insert(output, full_line)
          if trimmed_line:len() > longest then
            longest = full_line:len()
          end
        end
      end
    elseif line:len() > longest then
      longest = line:len()
      table.insert(output, line)
    else
      table.insert(output, line)
    end
  end

  return { output = output, longest = longest }
end

---Create a float relevant to the size of the content given and with borders.
---Big thanks to https://github.com/akinsho/dependency-assist.nvim where I stole
---a lot of the ideas and code from.
---@param contents table
---@param title string What you'd like displayed in the border.
---@return number win_id
M.make_float_with_borders = function(contents, title)
  -- The very max that we'll have the entire float
  local max_width = api.nvim_win_get_width(0) - 10

  local enforced_output = enforce_width(contents, max_width)
  local longest_line = enforced_output.longest
  local float_width = longest_line + 2

  local buf = api.nvim_create_buf(false, true)

  local title_line = insert_float_title(title, float_width, "─")
  local top = add_border(title_line, "top")

  local lines = {}
  table.insert(lines, top)

  for _, line in ipairs(enforced_output.output) do
    local trimmed = util.trim_end(line)
    local needed_padding = longest_line - #trimmed

    -- This sort of sucks, but it's the easiest thing to do right now since I
    -- know these two will be the only two that the Metals Doctor will send.
    -- In the future if that changes we may need to change this.
    if trimmed:find("⚠️") then
      needed_padding = needed_padding + 5
    elseif trimmed:find("✅") then
      needed_padding = needed_padding + 1
    end

    local extra_padding = string.rep(" ", needed_padding)
    local needs_border = trimmed .. extra_padding

    table.insert(lines, add_border(needs_border, "mid"))
  end

  local bot_line = string.rep("─", longest_line)
  local bot = add_border(bot_line, "bottom")

  table.insert(lines, bot)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  highlight_title(buf, title)
  local height = #lines
  local config = get_window_config(float_width, height, 0)
  local win_id = api.nvim_open_win(buf, false, config)
  vim.fn.win_gotoid(win_id)
  vim.bo[buf].ft = "markdown"
  return win_id
end

M.wrap_hover = function(bufnr, winnr)
  local hover_len = #api.nvim_buf_get_lines(bufnr, 0, -1, false)[1]
  local win_width = api.nvim_win_get_width(0)
  if hover_len > win_width then
    api.nvim_win_set_width(winnr, math.min(hover_len, win_width))
    api.nvim_win_set_height(winnr, math.ceil(hover_len / win_width))
    vim.wo[winnr].wrap = true -- luacheck: ignore 122
  end
end

return M
