local log = require("metals.log")

-- @param status (string) a new status to be displayed
local function set_status(status)
  -- Scaping the status to prevent % characters breaking the statusline
  local scaped_status = status:gsub('[%%]', '%%%1')
  vim.api.nvim_set_var("metals_status", scaped_status)
end

local function prompt_command(status)
  vim.ui.select({ "yes", "no" }, {
    prompt = string.format(
      "%s\nThere is a %s command attatched to this, would you like to execute it?",
      status.tooltip,
      status.command
    ),
  }, function(choice)
    if choice == "yes" then
      local client = vim.lsp.get_client_by_id(status.client_id)
      local fn = client.commands[status.command]
      if fn then
        fn(status.command, { bufnr = status.bufnr, client_id = status.client_id })
      else
        log.error_and_show(
          string.format(
            "It seems we don't implement %s as a client command. We should, tell Chris to fix this.",
            status.command
          )
        )
      end
    end
  end)
end

-- Used to handle the full status response from Metals
-- @param status (table) this is the normal status table as described in the
--                       metals docs as well as the bufnr and client_id.
local function handle_status(status)
  if status.hide then
    set_status("")
  else
    if status.text then
      set_status(status.text)
    end

    -- This status actually appears a lot in external sources, but really isn't
    -- a huge deal. In other editors like VS Code its fine becasue it doesn't
    -- steal your focus, but in nvim it does causing you to have to hit enter.
    -- Because of that when we see it we just ignore it.
    local annoyingMessage = "This external library source has compile errors."
    if status.command and status.tooltip then
      prompt_command(status)
    elseif status.tooltip and not string.find(status.tooltip, annoyingMessage) then
      log.warn_and_show(status.tooltip)
    end
  end
end

return {
  handle_status = handle_status,
  set_status = set_status,
}
