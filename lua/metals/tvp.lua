local api = vim.api
local lsp = vim.lsp

local log = require("metals.log")

local metals_packages = "metalsPackages"
local collapse_state = {
  expanded = "expanded",
  collapsed = "collapsed",
}

P = function(thing)
  print(vim.inspect(thing))
  return thing
end
-- interface TreeViewNode {
--   viewId: string;
--   nodeUri?: string;
--   label: string;
--   command?: Command;
--   icon?: string;
--   tooltip?: string;
--   collapseState?: "expanded" | "collapsed";
-- }

local state = {
  attatched_buf = nil,
  tvp_tree = nil,
}

local handlers = {}

local Node = {}
Node.__index = Node

function Node:new(raw_node)
  if not raw_node.viewId or not raw_node.label then
    log.error_and_show("Invalid node. Node must have a viewId and label.")
    log.error(raw_node)
  else
    local node = {}
    node.view_id = raw_node.viewId
    node.label = raw_node.label
    if raw_node.nodeUri ~= nil then
      node.node_uri = raw_node.nodeUri
    end
    if raw_node.command ~= nil then
      node.command = raw_node.command
    end
    if raw_node.icon ~= nil then
      node.icon = raw_node.icon
    end
    if raw_node.collapseState ~= nil then
      node.collapse_state = raw_node.collapseState
    end
    node.children = {}
    return setmetatable(node, self)
  end
end

-- Sends a request to the server to retrive the children of a given node_uri. If
-- the node_uri is absent we are dealing with the root node
-- @param view_id (string)
-- @param node_uri(string)
-- @returns (table) nodes
local function tree_view_children(view_id, parent_uri)
  local params = { viewId = view_id }
  if parent_uri ~= nil then
    params["nodeUri"] = parent_uri
  end
  vim.lsp.buf_request(state.attatched_buf, "metals/treeViewChildren", params, function(err, _, res)
    -- TODO handle err
    local new_nodes = {}
    for _, node in pairs(res.nodes) do
      table.insert(new_nodes, Node:new(node))
    end
    -- If this is nil we are dealing with a root element
    if parent_uri == nil then
      state.tvp_tree.children = new_nodes
    else
      state.tvp_tree:update(parent_uri, new_nodes)
    end
    state.tvp_tree:show()
  end)
end

-- Notify the server that the visiblity of a specific viewId has changed
-- @param view_id (string) the view_id that has changed visiblity
-- @param visible (boolean)
local function tree_view_visibility_did_change(view_id, visible)
  -- TODO this shouldn't always be zero it it won't send in when we are in the tvp panel
  vim.lsp.buf_notify(0, "metals/treeViewVisibilityDidChange", { viewId = view_id, visible = visible })
end

-- Notify the server that the collapse statet for a node has changed
-- @param view_id (string) the view id that contains the node
-- @param node_uri (string) uri of the node
-- @param collapsed (boolean)
local function tree_view_node_collapse_did_change(view_id, node_uri, collapsed)
  lsp.buf_notify(
    0,
    "metals/treeViewNodeCollapseDidChange",
    { viewId = view_id, nodeUri = node_uri, collapsed = collapsed }
  )
end

local function create_tvp_panel()
  -- TODO this should be pulled from a config
  vim.cmd("40vnew [tvp]")
  local win_id = api.nvim_get_current_win()
  local bufnr = api.nvim_get_current_buf()

  api.nvim_win_set_option(win_id, "spell", false)
  api.nvim_win_set_option(win_id, "number", false)
  api.nvim_win_set_option(win_id, "relativenumber", false)
  api.nvim_win_set_option(win_id, "cursorline", false)

  return {
    bufnr = bufnr,
    win_id = win_id,
  }
end

local function set_keymaps(bufnr)
  api.nvim_buf_set_keymap(
    bufnr,
    "n",
    "<CR>",
    [[<cmd>lua require("metals.tvp").toggle_node()<CR>]],
    { nowait = true, silent = true }
  )
end

local Tree = { bufnr = nil }

Tree.__index = Tree

function Tree:new(base_nodes)
  local root = Node:new({ label = metals_packages, viewId = metals_packages })
  return setmetatable(root, self)
end

function Tree:cache()
  state.tvp_tree = self
end

function Tree:set_lines(start_idx, end_idx, lines)
  -- grab buffer from state
  api.nvim_buf_set_option(0, "modifiable", true)
  api.nvim_buf_set_lines(0, start_idx, end_idx, true, lines)
  api.nvim_buf_set_option(0, "modifiable", false)
end

function Tree:show()
  local base_nodes = self.children

  local lines = {}
  local lookup = {}

  local line = 1
  local function iterate(nodes, level)
    for _, node in pairs(nodes) do
      local sign
      if node.collapse_state == collapse_state.collapsed then
        sign = "▸"
      elseif node.collapse_state == collapse_state.expanded then
        sign = "▾"
      else
        sign = " "
      end

      local space = string.rep(" ", level)
      table.insert(lines, space .. sign .. " " .. node.label)
      lookup[line] = node
      line = line + 1
      if #node.children ~= 0 and node.collapse_state == collapse_state.expanded then
        iterate(node.children, level + 1)
      end
    end
  end

  iterate(base_nodes, 0)

  self.lookup = lookup

  if self.win_id then
    self:set_lines(0, -1, lines)
  else
    local tvp_panel = create_tvp_panel()
    self.win_id = tvp_panel.win_id
    self.bufnr = tvp_panel.bufnr
    vim.cmd(string.format("buffer %d", tvp_panel.bufnr))
    self:set_lines(0, -1, lines)
    set_keymaps(tvp_panel.bufnr)
  end
end

function Tree:toggle()
  if self.bufnr == nil then
    tree_view_visibility_did_change(metals_packages, true)
    tree_view_children(metals_packages)
  elseif self.win_id == nil then
    tree_view_visibility_did_change(metals_packages, true)
    self:show()
  else
    tree_view_visibility_did_change(metals_packages, false)
    if api.nvim_win_is_valid(self.win_id) then
      api.nvim_win_close(self.win_id, true)
      self.win_id = nil
    end
  end
end

function Tree:toggle_node()
  local lnum, _ = unpack(vim.api.nvim_win_get_cursor(0))
  local node_info = self.lookup[lnum]

  if node_info.collapse_state == collapse_state.collapsed then
    node_info.collapse_state = collapse_state.expanded
    tree_view_node_collapse_did_change(metals_packages, node_info.node_uri, false)
    tree_view_children(node_info.view_id, node_info.node_uri)
  else
    node_info.collapse_state = collapse_state.collapsed
    tree_view_node_collapse_did_change(metals_packages, node_info.node_uri, true)
    self:show()
    -- TODO actually collapse and change ui
  end
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

handlers["metals/treeViewDidChange"] = function(_, _, nodes)
  if not state.tvp_tree then
    Tree:new(nodes):cache()
  else
    -- Figure out the update here
  end
end

handlers["metals/treeViewParent"] = function(err, _, tree_view_parent_result)
end

handlers["metals/treeViewReveal"] = function(err, _, tree_view_result)
end

local function tree_view_parent()
  vim.lsp.buf_request(0, "metals/treeViewParent", { viewId = metals_packages })
end

-- sends in TextDocumentPositionParams
local function tree_view_reveal()
  lsp.buf_request(0, "metals/treeViewReveal", {})
end

local function toggle_tree_view()
  if not state.tvp_tree then
    log.info_and_show("Tree view data has not yet been loaded. Wait until indexing finishes.")
  else
    local bufnr = api.nvim_get_current_buf()
    -- TODO does that have to keep being set?
    state.attatched_buf = bufnr
    state.tvp_tree:toggle()
  end
end

local function toggle_node()
  state.tvp_tree:toggle_node()
end

return {
  handlers = handlers,
  toggle_tree_view = toggle_tree_view,
  toggle_node = toggle_node,
  debug_tree = function()
    P(state)
  end,
}
