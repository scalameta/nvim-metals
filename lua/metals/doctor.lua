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
    local doctor_version = tonumber(args.version) or 0
    table.insert(output, "## Build Targets")

    if args.version then
      for _, target in ipairs(args.targets) do
        table.insert(output, "")
        table.insert(output, string.format("### %s", target.buildTarget))
        table.insert(output, string.format("  - target type: %s", target.targetType))
        if doctor_version >= 2 then
          table.insert(output, string.format("  - compilation: %s", target.compilationStatus))
        end
        table.insert(output, string.format("  - diagnostics: %s", target.diagnostics))
        table.insert(output, string.format("  - interactive: %s", target.interactive))
        table.insert(output, string.format("  - semanticdb: %s", target.semanticdb))
        table.insert(output, string.format("  - debugging: %s", target.debugging))
        table.insert(output, string.format("  - java: %s", target.java))
        if target.recommendation ~= "" then
          table.insert(output, string.format("  - recommendation: %s", target.recommendation))
        end
      end
      table.insert(output, "")
      table.insert(output, "## Explanations")
      for _, explanation in ipairs(args.explanations) do
        table.insert(output, "")
        table.insert(output, string.format("### %s", explanation.title))
        for _, deep_explanation in ipairs(explanation.explanations) do
          table.insert(output, string.format("%s", deep_explanation))
        end
      end
    else
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
      end
    end
  end

  local float = Float.percentage_range_window(0.6, 0.4, { winblend = 0 }, {
    title = args.title,
    titlehighlight = "MetalsTitle",
    topleft = "┌",
    topright = "┐",
    top = "─",
    left = "│",
    right = "│",
    botleft = "└",
    botright = "┘",
    bot = "─",
  })
  -- It's seemingly impossibly to get the hl to work for me with Float, so we
  -- just manually set them here.
  api.nvim_win_set_option(float.win_id, "winhl", "NormalFloat:Normal")
  api.nvim_win_set_option(float.border_win_id, "winhl", "NormalFloat:Normal")
  api.nvim_buf_set_option(float.bufnr, "filetype", "markdown")
  api.nvim_buf_set_lines(float.bufnr, 0, -1, false, output)
  doctor_win_id = float.win_id
end

return Doctor
