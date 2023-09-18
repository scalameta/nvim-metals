--
-- Big thanks to @akinsho, since most of this was copied and inspired from akinsho/flutter-tools.
--
local log = require("metals.log")
local commands_table = require("metals.commands").commands_table

local has_telescope, telescope = pcall(require, "telescope")

if not has_telescope then
  local msg = "Telescope must be installed to use this functionality (https://github.com/nvim-telescope/telescope.nvim)"
  log.error_and_show(msg)
end

local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local conf = require("telescope.config").values
local entry_display = require("telescope.pickers.entry_display")
local finders = require("telescope.finders")
local themes = require("telescope.themes")
local pickers = require("telescope.pickers")

local function execute_command(bufnr)
  local selection = action_state.get_selected_entry(bufnr)
  actions.close(bufnr)
  if selection then
    local cmd = selection.command
    local success, msg = pcall(cmd)
    if not success then
      vim.api.nvim_notify(msg, 2, {})
    end
  end
end

local function command_entry_maker(max_width)
  local make_display = function(en)
    local displayer = entry_display.create({
      separator = " - ",
      items = {
        { width = max_width },
        { remaining = true },
      },
    })

    return displayer({
      { en.label, "Type" },
      { en.hint, "Comment" },
    })
  end

  local function create_command(cmd_id)
    return require("metals")[cmd_id]
  end

  return function(entry)
    return {
      ordinal = entry.id,
      command = create_command(entry.id),
      hint = entry.hint,
      label = entry.label,
      display = make_display,
    }
  end
end

local function get_max_width(commands)
  local max = 0
  for _, value in ipairs(commands) do
    max = #value.label > max and #value.label or max
  end
  return max
end

local function commands(opts)
  opts = opts or themes.get_dropdown({
    previewer = false,
  })

  pickers
    .new(opts, {
      prompt_title = "Metals Commands",
      finder = finders.new_table({
        results = commands_table,
        entry_maker = command_entry_maker(get_max_width(commands_table)),
      }),
      sorter = conf.generic_sorter(opts),
      attach_mappings = function(_, map)
        map("i", "<CR>", execute_command)
        map("n", "<CR>", execute_command)

        -- If the return value of `attach_mappings` is true, then the other
        -- default mappings are still applies.
        -- Return false if you don't want any other mappings applied.
        -- A return value _must_ be returned. It is an error to not return anything.
        return true
      end,
    })
    :find()
end

return telescope.register_extension({
  exports = {
    commands = commands,
  },
})
