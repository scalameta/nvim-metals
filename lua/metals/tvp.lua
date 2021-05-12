local api = vim.api
local lsp = vim.lsp

local handlers = {}
-- interface TreeViewNode {
--   viewId: string;
--   nodeUri?: string;
--   label: string;
--   command?: Command;
--   icon?: string;
--   tooltip?: string;
--   collapseState?: "expanded" | "collapsed";
-- }

local tree_state = {}

local metals_packages = "metalsPackages"

handlers["metals/treeViewDidChange"] = function(err, _, nodes)
  -- TODO this probably isn't correct but for now, lets just set this
  tree_state = nodes
end

-- interface TreeViewChildrenResult {
--   /** The child nodes of the requested parent node. */
--   nodes: TreeViewNode[];
-- }
handlers["metals/treeViewChildren"] = function(err, _, tree_view_children_result)
  print(vim.inspect(tree_view_children_result))
end

-- interface TreeViewParentResult {
--   /** The parent node URI or undefined when the parent is the root node. */
--   uri?: string;
-- }
handlers["metals/treeViewParent"] = function(err, _, tree_view_parent_result)
end

-- interface MetalsTreeRevealResult {
--   /** The ID of the view that this node is associated with. */
--   viewId: string;
--   /**
--    * The list of URIs for the node to reveal and all of its ancestor parents.
--    *
--    * The node to reveal is at index 0, it's parent is at index 1 and so forth
--    * up until the root node.
--    */
--   uriChain: string[];
-- }
handlers["metals/treeViewReveal"] = function(err, _, tree_view_result)
end

-- Sends a request to the server to retrive the children of a given viewId
-- @param view_id (string)
-- @param node_uri(string)
-- @returns (table) nodes
local function tree_view_children(view_id, node_uri)
  local params = { viewId = view_id }
  if node_uri ~= nil then
    params["nodeUri"] = node_uri
  end
  vim.lsp.buf_request(0, "metals/treeViewChildren", params)
end

-- interface TreeViewParentParams {
--   /** The ID of the view that the nodeUri is associated with. */
--   viewId: string;
--   /** The URI of the child node. */
--   nodeUri: string;
-- }
local function tree_view_parent()
  vim.lsp.buf_request(0, "metals/treeViewChildren", { viewId = metals_packages })
end

-- Notify the server that the visiblity of a specific viewId has changed
-- @param view_id (string) the view_id that has changed visiblity
-- @param visible (boolean)
local function tree_view_visibility_did_change(view_id, visible)
  vim.lsp.buf_notify(0, "metals/treeViewVisibilityDidChange", { viewId = view_id, visible = visible })
end

-- interface TreeViewNodeCollapseDidChangeParams {
--   /** The ID of the view that this node is associated with. */
--   viewId: string;
--   /** The URI of the node that was collapsed or expanded. */
--   nodeUri: string;
--   /** True if the node is collapsed, false if the node was expanded. */
--   collapsed: boolean;
-- }
local function tree_view_node_collapse_did_change()
  lsp.buf_notify(0, "metals/treeViewNodeCollapseDidChange", {})
end

-- sends in TextDocumentPositionParams
local function tree_view_reveal()
  lsp.buf_request(0, "metals/treeViewReveal", {})
end

local function toggle_tree_view()
  -- TODO add in a check to see if there are any root nodes, if not dont't send in the requests
  tree_view_visibility_did_change(metals_packages, true)
  tree_view_children(metals_packages)

  --local buf = api.nvim_create_buf(false, false)

  --vim.cmd("vsplit")
  --vim.cmd(string.format("buffer %d", buf))

  --api.nvim_win_set_option(0, "spell", false)
  --api.nvim_win_set_option(0, "number", false)
  --api.nvim_win_set_option(0, "relativenumber", false)
  --api.nvim_win_set_option(0, "cursorline", false)

  --api.nvim_buf_set_lines(buf, 0, 0, false, output)
end
return {
  handlers = handlers,
  toggle_tree_view = toggle_tree_view,
}
