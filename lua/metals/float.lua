local api = vim.api

---@class BorderOpts
---@field title? string Window title
---@field titlehighlight? string Title highlight group
---@field topleft? string Top-left border character
---@field top? string Top border character
---@field topright? string Top-right border character
---@field right? string Right border character
---@field botright? string Bottom-right border character
---@field bot? string Bottom border character
---@field botleft? string Bottom-left border character
---@field left? string Left border character

---@class WinOpts
---@field winblend? number Window transparency (0-100)
---@field [string] any Other window options

---@class FloatWindow
---@field bufnr number Buffer number
---@field win_id number Window ID
---@field border_win_id number Border window ID (same as win_id for compatibility)

local M = {}

---Create a floating window with percentage-based dimensions
---@param width_percent number Width as percentage of screen (0.0-1.0)
---@param height_percent number Height as percentage of screen (0.0-1.0)
---@param win_opts? WinOpts Window configuration options
---@param border_opts BorderOpts Border configuration options
---@return FloatWindow window The created floating window
function M.percentage_range_window(width_percent, height_percent, win_opts, border_opts)
  local width = math.floor(vim.o.columns * width_percent)
  local height = math.floor(vim.o.lines * height_percent)

  local bufnr = api.nvim_create_buf(false, true)

  local win_config = {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = "minimal",
    border = {
      { border_opts.topleft or "┌", "Normal" },
      { border_opts.top or "─", "Normal" },
      { border_opts.topright or "┐", "Normal" },
      { border_opts.right or "│", "Normal" },
      { border_opts.botright or "┘", "Normal" },
      { border_opts.bot or "─", "Normal" },
      { border_opts.botleft or "└", "Normal" },
      { border_opts.left or "│", "Normal" },
    },
  }

  if border_opts.title then
    win_config.title = border_opts.title
    win_config.title_pos = "center"
  end

  for k, v in pairs(win_opts or {}) do
    if k ~= "winblend" then
      win_config[k] = v
    end
  end

  local win_id = api.nvim_open_win(bufnr, true, win_config)

  if win_opts and win_opts.winblend then
    api.nvim_set_option_value("winblend", win_opts.winblend, { win = win_id })
  end

  -- Set window highlights
  local winhl = "NormalFloat:Normal"
  if border_opts.titlehighlight then
    winhl = winhl .. ",FloatTitle:" .. border_opts.titlehighlight
  end
  api.nvim_set_option_value("winhl", winhl, { win = win_id })

  return {
    bufnr = bufnr,
    win_id = win_id,
    border_win_id = win_id,
  }
end

return M
