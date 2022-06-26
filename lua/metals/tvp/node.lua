local log = require("metals.log")
local util = require("metals.tvp.util")

-- Notify the server that the collapse stated for a node has changed
-- @param view_id (string) the view id that contains the node
-- @param node_uri (string) uri of the node
-- @param collapsed (boolean)
local function tree_view_node_collapse_did_change(bufnr, view_id, node_uri, collapsed)
  vim.lsp.buf_notify(
    bufnr,
    "metals/treeViewNodeCollapseDidChange",
    { viewId = view_id, nodeUri = node_uri, collapsed = collapsed }
  )
end

local Node = {}
Node.__index = Node

function Node:new(raw_node)
  if not raw_node.viewId or not raw_node.label then
    log.error_and_show("Invalid node. Node must have a viewId and a label.")
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

function Node:expand(bufnr)
  self.collapse_state = util.collapse_state.expanded
  tree_view_node_collapse_did_change(bufnr, self.view_id, self.node_uri, false)
end

function Node:collapse(bufnr)
  self.collapse_state = util.collapse_state.collapsed
  tree_view_node_collapse_did_change(bufnr, self.view_id, self.node_uri, true)
end

return Node
