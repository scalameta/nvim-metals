local log = require("metals.log")

-- @param status (string) a new status to be displayed
local function set_status(status)
  vim.api.nvim_set_var("metals_status", status)
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

    if status.command and status.tooltip then
      prompt_command(status)
    elseif status.tooltip then
      log.warn_and_show(status.tooltip)
    end
  end
end

return {
  handle_status = handle_status,
  set_status = set_status,
}
