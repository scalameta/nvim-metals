local api = vim.api
local fn = vim.fn
local lsp = vim.lsp

local decoration = require("metals.decoration")
local doctor = require("metals.doctor")
local log = require("metals.log")
local status = require("metals.status")
local test_explorer = require("metals.test_explorer")

local M = {}

-- Implementation of the `metals/quickPick` Metals LSP extension.
-- https://scalameta.org/metals/docs/integrations/new-editor/#metalsquickpick
M["metals/quickPick"] = function(_, result)
  local ids = {}
  local labels = {}
  for i, item in pairs(result.items) do
    table.insert(ids, item.id)
    table.insert(labels, i .. " - " .. item.label)
  end
  local choice = vim.fn.inputlist(labels)
  if choice == 0 then
    return { cancelled = true }
  else
    return { itemId = ids[choice] }
  end
end

-- Implementation of the `metals/inputBox` Metals LSP extension.
-- https://scalameta.org/metals/docs/integrations/new-editor#metalsinputbox
M["metals/inputBox"] = function(_, result)
  local args = { prompt = result.prompt .. "\n" }

  if result.value then
    args.default = result.value
  end

  local name = vim.fn.input(args)

  if name == "" then
    return { cancelled = true }
  else
    return { value = name }
  end
end

-- Implementation of the `metals/executeClientCommand` Metals LSP extension.
-- - https://scalameta.org/metals/docs/integrations/new-editor#metalsexecuteclientcommand
M["metals/executeClientCommand"] = function(_, result)
  if result.command == "metals-goto-location" then
    lsp.util.jump_to_location(result.arguments[1], "utf-16")
  elseif result.command == "metals-doctor-run" then
    local args = fn.json_decode(result.arguments[1])
    doctor.create(args)
  elseif result.command == "metals-doctor-reload" then
    if doctor.is_open() then
      doctor.close()
      local args = fn.json_decode(result.arguments[1])
      doctor.create(args)
    end
  elseif result.command == "metals-diagnostics-focus" then
    vim.diagnostic.setqflist({ severity = "E" })
  elseif result.command == "metals-model-refresh" then
    lsp.codelens.refresh()
  elseif result.command == "metals-update-test-explorer" then
    test_explorer.update_state(result.arguments)
  else
    log.warn_and_show(string.format("Looks like nvim-metals doesn't handle %s yet.", result.command))
  end
end

-- Callback function to handle `metals/status`
-- This sets a global variable `metals_status` which can be easily
-- picked up and used in a statusline.
-- NOTE: We also just add the bufnr and client_id right into here to be potentially
-- used if needed later on if there is a tooltip and command attatched to the status.
-- https://scalameta.org/metals/docs/integrations/new-editor/#metalsstatus
M["metals/status"] = function(_, _status, ctx)
  _status.bufnr = ctx.bufnr
  _status.client_id = ctx.client_id
  status.handle_status(_status)
end

-- Function needed to implement the Decoration Protocol from Metals.
-- - https://scalameta.org/metals/docs/integrations/decoration-protocol
M["metals/publishDecorations"] = function(err, result)
  if err then
    log.error_and_show("Server error while publishing decorations. Please see logs for details.")
    log.error(err.message)
  end
  if not result then
    return
  end

  local uri = result.uri
  local bufnr = vim.uri_to_bufnr(uri)

  if not bufnr then
    log.warn_and_show(string.format("Couldn't find buffer for %s while publishing decorations.", uri))
    return
  end

  -- Unloaded buffers should not handle diagnostics.
  -- When the buffer is loaded, we'll call on_attach, which sends textDocument/didOpen.
  if not api.nvim_buf_is_loaded(bufnr) then
    return
  end

  decoration.clear(bufnr)

  for _, deco in ipairs(result.options) do
    decoration.set_decoration(bufnr, deco)
  end
end

-- https://scalameta.org/metals/docs/integrations/new-editor/#metalsfindtextindependencyjars
M["metals/findTextInDependencyJars"] = function(_, result, _, config)
  if not result or vim.tbl_isempty(result) then
    vim.notify("Nothing found in jars files.")
  else
    config = config or {}
    if config.loclist then
      vim.fn.setloclist(0, {}, " ", {
        title = "Language Server",
        items = lsp.util.locations_to_items(result, "utf-16"),
      })
      api.nvim_command("lopen")
    else
      vim.fn.setqflist({}, " ", {
        title = "Language Server",
        items = lsp.util.locations_to_items(result, "utf-16"),
      })
      api.nvim_command("copen")
    end
  end
end

return M
