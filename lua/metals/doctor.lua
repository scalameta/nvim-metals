local api = vim.api
local lsp = vim.lsp

local log = require("metals.log")
local has_plenary, Float = pcall(require, "plenary.window.float")

if not has_plenary then
  log.warn_and_show("Some features won't work without plenary installed. Please install nvim-lua/plenary.nvim")
end

--- Module meant to control the Metals doctor.
--- It doesn't do a whole lot except create the doctor, and only
--- make sure there is one open at one time.
local Doctor = {}

--- Last win_id of the open doctor, if any.
local doctor_win_id = nil

--- Determine if the doctor is open by checking whether the doctor_win_id is
-- set and it's a valid win_id.
---@return boolean
Doctor.is_open = function()
  if doctor_win_id and api.nvim_win_is_valid(doctor_win_id) then
    return true
  else
    return false
  end
end

--- Close doctor. Pretty much only used if the doctor
--- is open and the reload doctor command comes in.
Doctor.close = function()
  api.nvim_win_close(doctor_win_id, true)
end

--- Create the Doctor.
-- @param args table of the args give by `metals/executeClientCommand`
Doctor.create = function(args)
  local header_text = lsp.util.convert_input_to_markdown_lines({ args.headerText })
  local output = header_text
  table.insert(output, "")

  if args.messages then
    for _, message in ipairs(args.messages) do
      table.insert(output, string.format("## %s", message.title))

      table.insert(output, "")
      for _, recommendation in ipairs(message.recommendations) do
        table.insert(output, string.format("  - %s", recommendation))
      end
    end
  else
    table.insert(output, "## Build Targets")

    for _, target in ipairs(args.targets) do
      table.insert(output, "")
      table.insert(output, string.format("### %s", target.buildTarget))
      table.insert(output, string.format("  - scala version: %s", target.scalaVersion))
      table.insert(output, string.format("  - diagnostics: %s", target.diagnostics))
      table.insert(output, string.format("  - goto definition: %s", target.gotoDefinition))
      table.insert(output, string.format("  - completions: %s", target.completions))
      table.insert(output, string.format("  - find references: %s", target.findReferences))
      if target.recommendation ~= "" then
        table.insert(output, string.format("  - recommendation: %s", target.recommendation))
      end
      table.insert(output, "")
    end
  end

  --local win_id = ui.make_float_with_borders(output, args.title)
  --doctor_win_id = win_id

  local float = Float.percentage_range_window(0.8, 0.6, {}, { title = args.title })
  api.nvim_buf_set_lines(float.bufnr, 0, -1, false, output)
  doctor_win_id = float.win_id
  vim.lsp.util.close_preview_autocmd({ "BufHidden", "BufLeave" }, float.win_id)
end

return Doctor
