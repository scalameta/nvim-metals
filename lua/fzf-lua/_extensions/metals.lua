local log = require("metals.log")
local commands_table = require("metals.commands").commands_table

local has_fzf, fzf = pcall(require, "fzf-lua")

if not has_fzf then
  local msg = "fzf-lua must be installed to use this functionality (https://github.com/ibhagwan/fzf-lua)"
  log.error_and_show(msg)
end

local function run_entry(entry)
  local command = require("metals")[entry.id]
  local success, msg = pcall(command)
  if not success then
    vim.api.nvim_notify(msg, 2, {})
  end
end

local function run_selected(label)
  for _, entry in ipairs(commands_table) do
    if entry.label == label then
      run_entry(entry)
      return
    end
  end
end

return function()
  local labels = {}
  for _, entry in ipairs(commands_table) do
    table.insert(labels, entry.label)
  end

  return fzf.fzf_exec(labels, {
    prompt = "Metals Commands> ",
    previewer = false,
    actions = {
      ["default"] = function(sel)
        run_selected(sel[1])
      end,
    },
  })
end
