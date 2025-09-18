local api = vim.api
local lsp = vim.lsp

local log = require("metals.log")
local messages = require("metals.messages")
local Node = require("metals.tvp.node")
local tvp_util = require("metals.tvp.util")
local util = require("metals.util")

local collapse_state = tvp_util.collapse_state
local metals_packages = tvp_util.metals_packages

local default_config = {
  panel_width = 40,
  panel_alignment = "left",
  toggle_node_mapping = "<CR>",
  node_command_mapping = "r",
  collapsed_sign = "▸",
  expanded_sign = "▾",
  icons = {
    enabled = false,
    symbols = {
      object = "",
      trait = "",
      class = "ﭰ",
      interface = "",
      val = "",
      var = "",
      method = "ﬦ",
      enum = "",
      field = "",
      package = "",
    },
  },
}

local config = nil

local state = {
  -- NOTE: this is a bit of a hack since once we create the tvp panel, we can
  -- no longer use 0 as the buffer to send the requests so we store a valid
  -- buffer that Metals is attatched to. It doesn't really matter _what's_ in
  -- that buffer, as long as Metals is attatched.
  attatched_bufnr = nil,
  tvp_tree = nil,
}

-- Used to setup the TVP panel config.
-- @param user_config (table) Pulled from the tvp key of the table passed into `initialize_or_attach`.
local function setup_config(user_config)
  if config == nil then
    config = util.check_exists_and_merge(default_config, user_config or {})
  end
end

local handlers = {}

local function valid_metals_buffer()
  if api.nvim_buf_is_loaded(state.attatched_bufnr) then
    return state.attatched_bufnr
  else
    local valid_buf = util.find_metals_buffer()
    state.attatched_bufnr = valid_buf
    return valid_buf
  end
end

local function tvp_panel_is_open(win_id)
  if win_id == nil or not api.nvim_win_is_valid(win_id) then
    return false
  else
    return true
  end
end

-- Notify the server that the visiblity of a specific viewId has changed
-- @param view_id (string) the view_id that has changed visiblity
-- @param visible (boolean)
local function tree_view_visibility_did_change(view_id, visible)
  vim.lsp.buf_notify(
    valid_metals_buffer(),
    "metals/treeViewVisibilityDidChange",
    { viewId = view_id, visible = visible }
  )
end

local function create_tvp_panel()
  local alignment
  if config.panel_alignment == "right" then
    alignment = "botright"
  elseif config.panel_alignment == "left" then
    alignment = "topleft"
  else
    log.warn_and_show(
      string.format("%s is an invalid option for panel_alignment. Must choose left or right.", config.panel_alignment)
    )
  end
  vim.cmd(string.format("silent %s vertical %d new [tvp]", alignment, config.panel_width))
  local win_id = api.nvim_get_current_win()
  local bufnr = api.nvim_get_current_buf()

  api.nvim_set_option_value("spell", false, { win = win_id })
  api.nvim_set_option_value("number", false, { win = win_id })
  api.nvim_set_option_value("relativenumber", false, { win = win_id })
  api.nvim_set_option_value("cursorline", false, { win = win_id })
  api.nvim_set_option_value("filetype", "tvp", { buf = bufnr })
  api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })

  return {
    bufnr = bufnr,
    win_id = win_id,
  }
end

local function set_keymaps(bufnr)
  api.nvim_buf_set_keymap(
    bufnr,
    "n",
    config.toggle_node_mapping,
    [[<cmd>lua require("metals.tvp").toggle_node()<CR>]],
    { nowait = true, silent = true }
  )
  api.nvim_buf_set_keymap(
    bufnr,
    "n",
    config.node_command_mapping,
    [[<cmd>lua require("metals.tvp").node_command()<CR>]],
    { nowait = true, silent = true }
  )
end

local Tree = { bufnr = nil }

Tree.__index = Tree

function Tree:new()
  -- In reality this should take root nodes, but since we are only implementing
  -- metalsPackages, we just auto make that the root
  local root = Node:new({ label = metals_packages, viewId = metals_packages })
  return setmetatable(root, self)
end

-- Sends a request to the server to retrieve the children of a given node_uri. If
-- the node_uri is absent we are dealing with the root node
-- @param view_id (string)
-- @param node_uri (string)
-- @param opts (table) The opts table has the following keys:
--  additionals (table)
--  expland (boolean)
--  focus (boolean)
--  parent_uri (string)
--  view_id (string)
function Tree:tree_view_children(opts)
  local view_id = opts.view_id
  opts = opts or {}
  local tree_view_children_params = { viewId = view_id }
  if opts.parent_uri ~= nil then
    tree_view_children_params["nodeUri"] = opts.parent_uri
  end

  local metals_id = util.find_metals_client_id()
  local client = lsp.get_client_by_id(metals_id)

  client:request("metals/treeViewChildren", tree_view_children_params, function(err, result, ctx)
    local response = { err = err, result = result, ctx = ctx }

    if response.err then
      log.error(response.err)
      log.error_and_show("Something went wrong while requesting tvp children. More info in logs.")
    else
      local new_nodes = {}
      for _, node in pairs(response.result.nodes) do
        table.insert(new_nodes, Node:new(node))
      end
      if opts.parent_uri == nil then
        self.children = new_nodes
      else
        self:update(opts.parent_uri, new_nodes)
      end
      -- NOTE: Not ideal to have to iterate over these again, but we want the
      -- update to happen before we call this or else we'll have issues adding the
      -- children to a node that doesn't yet exist.
      for _, node in pairs(new_nodes) do
        if node.collapse_state == collapse_state.expanded then
          self:tree_view_children({ view_id = metals_packages, parent_uri = node.node_uri })
        end
      end
      if opts.expand then
        local node = self:find(opts.parent_uri)
        if node and node.collapse_state and node.collapse_state == collapse_state.collapsed then
          node:expand(valid_metals_buffer())
        end
      end
      local additionals = opts.additionals
      if additionals then
        local head = table.remove(additionals, 1)
        local additional_params = {
          view_id = view_id,
          parent_uri = head,
          expand = opts.expand,
          focus = opts.focus,
        }
        if #additionals > 1 then
          additional_params.additionals = additionals
        end
        self:tree_view_children(additional_params)
      end

      self:reload_and_show()
      if opts.focus and not opts.additionals then
        for line, node in pairs(self.lookup) do
          if node.node_uri == opts.parent_uri then
            api.nvim_win_set_cursor(self.win_id, { line, 0 })
            break
          end
        end
      end
    end
  end, valid_metals_buffer())
end

function Tree:cache()
  state.tvp_tree = self
end

function Tree:set_lines(start_idx, end_idx, lines)
  -- NOTE: We are replacing the entire buffer with set_lines. If performance
  -- ever becomes an issue it may be better to _only_ update the nodes that
  -- have changed and their children. For now this seems fast enough to just
  -- not care
  api.nvim_set_option_value("modifiable", true, { buf = self.bufnr })
  api.nvim_buf_set_lines(self.bufnr, start_idx, end_idx, true, lines)
  api.nvim_set_option_value("modifiable", false, { buf = self.bufnr })
end

local function get_sign(node)
  local sign = " "
  if node.collapse_state == collapse_state.collapsed then
    sign = config.collapsed_sign
  elseif node.collapse_state == collapse_state.expanded then
    sign = config.expanded_sign
  end
  return sign
end

local function get_icon(node)
  if not config.icons.enabled then
    return ""
  end
  local icon = config.icons.symbols.package
  if node.icon ~= nil then
    icon = config.icons.symbols[node.icon]
    if icon == nil then
      icon = " "
    end
  end
  return " " .. icon
end

function Tree:reload_and_show()
  local base_nodes = self.children

  local lines = {}
  local lookup = {}

  local line = 1
  local function iterate(nodes, level)
    for _, node in pairs(nodes) do
      local sign = get_sign(node)
      local icon = get_icon(node)
      local space = string.rep(" ", level)
      table.insert(lines, space .. sign .. icon .. " " .. node.label)
      lookup[line] = node
      line = line + 1
      if #node.children ~= 0 and node.collapse_state == collapse_state.expanded then
        iterate(node.children, level + 1)
      end
    end
  end

  iterate(base_nodes, 0)

  self.lookup = lookup

  if self.win_id and api.nvim_win_is_valid(self.win_id) then
    self:set_lines(0, -1, lines)
  else
    local tvp_panel = create_tvp_panel()
    self.win_id = tvp_panel.win_id
    self.bufnr = tvp_panel.bufnr

    api.nvim_create_autocmd({ "BufDelete" }, {
      buffer = tvp_panel.bufnr,
      callback = function()
        self:close()
      end,
      group = api.nvim_create_augroup("nvim-tvp", {}),
    })

    vim.cmd(string.format("buffer %d", tvp_panel.bufnr))
    self:set_lines(0, -1, lines)
    set_keymaps(tvp_panel.bufnr)
  end
end

function Tree:open()
  if self.bufnr then
    self:reload_and_show()
  else
    self:tree_view_children({ view_id = metals_packages })
  end
  tree_view_visibility_did_change(metals_packages, true)
end

function Tree:close()
  tree_view_visibility_did_change(metals_packages, false)
  if api.nvim_win_is_valid(self.win_id) then
    api.nvim_win_close(self.win_id, true)
    self.win_id = nil
  end
end

function Tree:toggle()
  if not tvp_panel_is_open(self.win_id) then
    self:open()
  else
    self:close()
  end
end

local function execute_node_command(node)
  if node.command ~= nil then
    -- Jump to the last window so this doesn't open up in the actual tvp panel
    vim.cmd([[wincmd p]])

    local metals_id = util.find_metals_client_id()
    local client = lsp.get_client_by_id(metals_id)

    client.request("workspace/executeCommand", {
      command = node.command.command,
      arguments = node.command.arguments,
    }, function(err, _, _)
      if err then
        log.error_and_show("Unable to execute node command.")
      end
    end, valid_metals_buffer())
  end
end

function Tree:toggle_node()
  local lnum, _ = unpack(vim.api.nvim_win_get_cursor(0))
  local node = self.lookup[lnum]

  if node.collapse_state == collapse_state.collapsed then
    node:expand(valid_metals_buffer())
    -- If the node already has children we can assume that request has already
    -- been made and therefore don't send it again, we just reload the UI and
    -- show it.
    if #node.children > 0 then
      self:reload_and_show()
    else
      self:tree_view_children({ view_id = node.view_id, parent_uri = node.node_uri })
    end
  elseif node.collapse_state == collapse_state.expanded then
    node:collapse(valid_metals_buffer())
    self:reload_and_show()
  else
    execute_node_command(node)
  end
end

function Tree:node_command()
  local lnum, _ = unpack(vim.api.nvim_win_get_cursor(0))
  local node = self.lookup[lnum]
  execute_node_command(node)
end

function Tree:update(parent_uri, new_nodes)
  local function recurse(node)
    if node.node_uri ~= parent_uri then
      for _, child_node in pairs(node.children) do
        recurse(child_node)
      end
    else
      node.children = new_nodes
    end
  end

  recurse(self)
  return self
end

function Tree:find(uri)
  local found_node = nil

  local function search(nodes)
    for _, node in pairs(nodes) do
      if node.node_uri == uri then
        found_node = node
        break
      elseif #node.children > 0 then
        search(node.children)
      end
    end
  end

  search(self.children)

  return found_node
end

handlers["metals/treeViewDidChange"] = function(_, result)
  if not state.tvp_tree then
    Tree:new():cache()
  else
    -- TODO An improvement here would be to remember the old collapsed state of
    -- a node before replacing it. While this works, you end up with a node that
    -- was expanded previously, then replaced, and then now collapsed since
    -- that's the state the new node comes with. It'd be nicer to remember that
    -- old state and mimic the "collapsed" state.
    for _, node in pairs(result.nodes) do
      local new_node = Node:new(node)
      state.tvp_tree:update(new_node.node_uri, {})
      -- As far as I know, the res.nodes here will never be children of eachother, so we
      -- should be safe doing this call for the children in the same loop as the update.
      if new_node.collapse_state == collapse_state.expanded then
        state.tvp_tree:tree_view_children({ view_id = metals_packages, parent_uri = new_node.node_uri })
      end
    end
  end
end

local function ensure_tree_exists_then(fn)
  if not state.tvp_tree then
    log.warn_and_show("Tree view data has not yet been loaded. Wait until indexing finishes.")
  else
    state.attatched_bufnr = api.nvim_get_current_buf()
    fn()
  end
end

local function toggle_tree_view()
  ensure_tree_exists_then(function()
    state.tvp_tree:toggle()
  end)
end

local function toggle_node()
  state.tvp_tree:toggle_node()
end

local function node_command()
  state.tvp_tree:node_command()
end

local function reveal_in_tree()
  ensure_tree_exists_then(function()
    local params = lsp.util.make_position_params()

    if not tvp_panel_is_open(state.tvp_tree.win_id) then
      state.tvp_tree:open()
    end

    local metals_id = util.find_metals_client_id()
    local client = lsp.get_client_by_id(metals_id)

    client:request("metals/treeViewReveal", params, function(err, result, ctx)
      local response = { err = err, result = result, ctx = ctx }

      if response.err then
        log.error_and_show(
          string.format("Error when executing: %s. Check the metals logs for more info.", response.ctx.method)
        )
      elseif response.result then
        if response.result.viewId == metals_packages then
          if api.nvim_get_current_win() ~= state.tvp_tree.win_id then
            vim.fn.win_gotoid(state.tvp_tree.win_id)
          end

          util.reverse(response.result.uriChain)
          local head = table.remove(response.result.uriChain, 1)

          state.tvp_tree:tree_view_children({
            view_id = response.result.viewId,
            parent_uri = head,
            additionals = response.result.uriChain,
            expand = true,
            focus = true,
          })
        else
          log.warn_and_show(
            string.format("You recieved a node for a view nvim-metals doesn't support: %s", response.result.viewId)
          )
        end
      else
        log.warn_and_show(messages.scala_3_tree_view)
      end
    end, valid_metals_buffer())
  end)
end

return {
  handlers = handlers,
  node_command = node_command,
  reveal_in_tree = reveal_in_tree,
  setup_config = setup_config,
  toggle_node = toggle_node,
  toggle_tree_view = toggle_tree_view,
}
