local api = vim.api

local M = {}

local state = {is_open = false, current = nil, enclosing_window = nil}

--- @param line string
local function pad(line)
  return ' ' .. line .. ' '
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
  if position == 'top' then
    return '╭' .. item .. '╮'
  elseif position == 'mid' then
    return '│' .. item .. '│'
  elseif position == 'bottom' then
    return '╰' .. item .. '╯'
  end
end

--- @param buf number
--- @param title string
local function highlight_title(buf, title)
  if not title then
    return
  end
  local start_col = 4
  api.nvim_buf_add_highlight(buf, -1, -- Namespace ID
  'Title', -- Highlight group
  0, -- line number
  start_col, -- start
  start_col + title:len() -- end
  )
end

---Get basic configuration to give to nvim_open_win()
---@param width number
---@param height number
---@return table
local function get_window_config(width, height)
  local win_width = api.nvim_win_get_width(state.enclosing_window)
  local row = math.floor((vim.o.lines * 0.5 - vim.o.cmdheight - 1) / 2)
  local col = math.floor((win_width - width) / 2)
  return {
    relative = 'win',
    width = width,
    height = height,
    col = col,
    row = row,
    style = 'minimal',
    focusable = false
  }
end

---Create a float relevant to the size of the content given and with borders.
---Big thanks to https://github.com/akinsho/dependency-assist.nvim where I stole
---a lot of the ideas and code from.
---@param contents table
---@param title string What you'd like displayed in the border.
---@return number win_id
M.make_float_with_borders = function(contents, title)
  local lines = {}

  -- For now I know this will be short since I pretty much fully control what
  -- I put it in, but it might be that we want to check win_width() here if
  -- we have issues with the window beign too wide.
  local longest_line = 0

  for _, line in ipairs(contents) do
    if line:len() > longest_line then
      longest_line = line:len()
    end
  end

  local win_width = longest_line + 2

  local buf = api.nvim_create_buf(false, true)

  local title_line = insert_float_title(title, win_width, '─')
  local top = add_border(title_line, 'top')

  table.insert(lines, top)

  for _, line in ipairs(contents) do
    -- trim trailing whitespace and trailing empty lines
    local trimmed = string.gsub(line, '[ \t]+%f[\r\n%z]', '')
    local needed_padding = longest_line - #trimmed
    local extra_padding = string.rep(' ', needed_padding)
    local needs_border = trimmed .. extra_padding

    table.insert(lines, add_border(needs_border, 'mid'))
  end

  local bot_line = string.rep('─', longest_line)
  local bot = add_border(bot_line, 'bottom')

  table.insert(lines, bot)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  highlight_title(buf, title)
  local height = #lines
  local config = get_window_config(win_width, height)
  local win_id = api.nvim_open_win(buf, false, config)
  vim.fn.win_gotoid(win_id)
  vim.bo[buf].ft = 'markdown'
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
