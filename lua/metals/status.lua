local log = require("metals.log")

-- @param status (string) a new status to be displayed
local function set_status(status, type)
  -- Not really sure why but this is at times getting called when status is nil
  -- so in that scenario we just do nothing
  if status ~= nil then
    -- Scaping the status to prevent % characters breaking the statusline
    local scaped_status = status:gsub("[%%]", "%%%1")
    local _status = "_status"
    local metals = "metals"
    local status_var = nil
    if type and type == metals then
      status_var = type .. _status
    elseif type then
      status_var = "metals_" .. type .. _status
    else
      status_var = metals .. _status
    end
    vim.api.nvim_set_var(status_var, scaped_status)
  end
end

-- Used to handle the full status response from Metals
-- @param status (table) this is the normal status table as described in the
--                       metals docs as well as the bufnr and client_id.
local function handle_status(status)
  local type = status.statusType
  if status.hide then
    set_status("", type)
    vim.cmd.redrawstatus()
  else
    if status.text then
      set_status(status.text, type)
      vim.cmd.redrawstatus()
    end

    -- NOTE: I decided not to show this to the user since it's causing too many problems always
    -- popping up and not providing any value.
    -- I've yet to find a good way to support the status tooltips that don't steal the focus, but
    -- allow you to select them if you choose. For now, we'll just comment it out and log them
    -- to see if the amount of people complaining about the popups goes away and if no other issues
    -- surface.
    if status.command and status.tooltip then
      log.warn(status.tooltip)
    end
  end
end

return {
  handle_status = handle_status,
  set_status = set_status,
}
