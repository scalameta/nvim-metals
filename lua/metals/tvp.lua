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

local state = {
  -- NOTE: this is a bit of a hack since once we create the tvp panel, we can
  -- no longer use 0 as the buffer to send the requests so we store a valid
  -- buffer that Metals is attatched to. It doesn't really matter _whats_ in
  -- that buffer, as long as Metals is attatched.
  attatched_bufnr = nil,
  tvp_tree = nil,
}

local handlers = {}

-- Notify the server that the collapse statet for a node has changed
-- @param view_id (string) the view id that contains the node
-- @param node_uri (string) uri of the node
-- @param collapsed (boolean)
local function tree_view_node_collapse_did_change(view_id, node_uri, collapsed)
  lsp.buf_notify(
    state.attatched_bufnr or 0,
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

function Node:expand()
  self.collapse_state = collapse_state.expanded
  tree_view_node_collapse_did_change(self.view_id, self.node_uri, false)
end

function Node:collapse()
  self.collapse_state = collapse_state.collapsed
  tree_view_node_collapse_did_change(self.view_id, self.node_uri, true)
end

-- Notify the server that the visiblity of a specific viewId has changed
-- @param view_id (string) the view_id that has changed visiblity
-- @param visible (boolean)
local function tree_view_visibility_did_change(view_id, visible)
  vim.lsp.buf_notify(
    state.attatched_bufnr or 0,
    "metals/treeViewVisibilityDidChange",
    { viewId = view_id, visible = visible }
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

  -- TODO Maybe possible to add tvp to filteypes for metals to attatch to in
  -- order to avoid the whole attatched_bufnr hack
  api.nvim_buf_set_option(bufnr, "filetype", "tvp")
  api.nvim_buf_set_option(bufnr, "buftype", "nofile")

  return {
    bufnr = bufnr,
    win_id = win_id,
  }
end

local function set_keymaps(bufnr)
  -- TODO pull all of these from a config
  api.nvim_buf_set_keymap(
    bufnr,
    "n",
    "<CR>",
    [[<cmd>lua require("metals.tvp").toggle_node()<CR>]],
    { nowait = true, silent = true }
  )
  api.nvim_buf_set_keymap(
    bufnr,
    "n",
    "r",
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

-- Sends a request to the server to retrive the children of a given node_uri. If
-- the node_uri is absent we are dealing with the root node
-- @param view_id (string)
-- @param node_uri(string)
function Tree:tree_view_children(opts)
  local view_id = opts.view_id
  opts = opts or {}
  local params = { viewId = view_id }
  if opts.parent_uri ~= nil then
    params["nodeUri"] = opts.parent_uri
  end
  vim.lsp.buf_request(state.attatched_bufnr, "metals/treeViewChildren", params, function(err, _, res)
    if err then
      log.error(err)
      log.error_and_show(err)
      log.error_and_show("Something went wrong while requesting tvp children.")
    else
      local new_nodes = {}
      for _, node in pairs(res.nodes) do
        table.insert(new_nodes, Node:new(node))
      end
      if opts.parent_uri == nil then
        self.children = new_nodes
      else
        self:update(opts.parent_uri, new_nodes)
      end
      -- TODO can we do this in a way we don't have to iterate over the nodes twice?
      -- NOTE: Not ideal to have to iterate over these again, but we want the
      -- update to happene before we call this or else we'll have issues adding the
      -- children to a node that doesn't yet exist.
      for _, node in pairs(new_nodes) do
        if node.collapse_state == collapse_state.expanded then
          self:tree_view_children({ view_id = metals_packages, parent_uri = node.node_uri })
        end
      end
      if opts.expand then
        local node = self:find(opts.parent_uri)
        if node and node.collapse_state and node.collapse_state == collapse_state.collapsed then
          node:expand()
        end
      end
      local additionals = opts.additionals
      if additionals and #additionals > 1 then
        local head = table.remove(additionals, 1)
        self:tree_view_children({ view_id = view_id, parent_uri = head, additionals = additionals, expand = opts.expand })
      elseif additionals and #additionals == 1 then
        self:tree_view_children({ view_id = view_id, parent_uri = additionals[1], expand = opts.expand })
      end
      self:reload_and_show()
    end
  end)
end

function Tree:cache()
  state.tvp_tree = self
end

function Tree:set_lines(start_idx, end_idx, lines)
  -- NOTE We are replacing the entire buffer with set_lines. If performance
  -- every becomes an issue it may be better to _only_ update the nodes that
  -- have changed and their children. For now this seems fast enough to just
  -- not care
  api.nvim_buf_set_option(self.bufnr, "modifiable", true)
  api.nvim_buf_set_lines(self.bufnr, start_idx, end_idx, true, lines)
  api.nvim_buf_set_option(self.bufnr, "modifiable", false)
end

function Tree:reload_and_show()
  local base_nodes = self.children

  local lines = {}
  local lookup = {}

  local line = 1
  local function iterate(nodes, level)
    for _, node in pairs(nodes) do
      local sign
      if node.collapse_state == collapse_state.collapsed then
        -- TODO grab these from a config
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

  if self.win_id and api.nvim_win_is_valid(self.win_id) then
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
  if self.win_id == nil or not api.nvim_win_is_valid(self.win_id) then
    self:open()
  else
    self:close()
  end
end

function Tree:toggle_node()
  local lnum, _ = unpack(vim.api.nvim_win_get_cursor(0))
  local node = self.lookup[lnum]

  if node.collapse_state == collapse_state.collapsed then
    node:expand()
    -- If the node already has children we can assume that request has already
    -- been made and therefore don't send it again, we just reload the UI and
    -- show it.
    if #node.children > 0 then
      self:reload_and_show()
    else
      self:tree_view_children({ view_id = node.view_id, parent_uri = node.node_uri })
    end
  elseif node.collapse_state == collapse_state.expanded then
    node:collapse()
    self:reload_and_show()
  end
end

function Tree:node_command()
  local lnum, _ = unpack(vim.api.nvim_win_get_cursor(0))
  local node_info = self.lookup[lnum]

  if node_info.command ~= nil then
    -- Jump to the last window so this doesn't open up in the actual tvp panel
    vim.cmd([[wincmd p]])
    vim.lsp.buf_request(state.attatched_bufnr, "workspace/executeCommand", {
      command = node_info.command.command,
      arguments = node_info.command.arguments,
    }, function(err, _, _)
      if err then
        log.error_and_show("Unable to execute node command.")
      end
    end)
  end
end

-- TODO maybe this should be named replace
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

handlers["metals/treeViewDidChange"] = function(_, _, res)
  if not state.tvp_tree then
    Tree:new():cache()
  else
    -- TODO An improvement here would be to remember the old collapsed state of
    -- a node before replacing it. While this works, you end up with a node that
    -- was expanded previously, then replaced, and then now collapsed since
    -- that's the state the new node comes with. It'd be nicer to remember that
    -- old state and mimic the "collapsed" state.
    for _, node in pairs(res.nodes) do
      local new_node = Node:new(node)
      state.tvp_tree:update(new_node.node_uri, {})
      -- As far as I know, the res.nodes here will never be children of eachother, so we
      -- should be safe doing this call for the children int he same loop as the update.
      if new_node.collapse_state == collapse_state.expanded then
        state.tvp_tree:tree_view_children({ view_id = metals_packages, parent_uri = new_node.node_uri })
      end
    end
  end
end

handlers["metals/treeViewParent"] = function(err, _, tree_view_parent_result)
end

local function tree_view_parent()
  vim.lsp.buf_request(0, "metals/treeViewParent", { viewId = metals_packages })
end

local function toggle_tree_view()
  if not state.tvp_tree then
    log.info_and_show("Tree view data has not yet been loaded. Wait until indexing finishes.")
  else
    local bufnr = api.nvim_get_current_buf()
    -- TODO does that have to keep being set?
    state.attatched_bufnr = bufnr
    state.tvp_tree:toggle()
  end
end

local function toggle_node()
  state.tvp_tree:toggle_node()
end

local function node_command()
  state.tvp_tree:node_command()
end

local function reverse(t)
  for i = 1, math.floor(#t / 2) do
    local j = #t - i + 1
    t[i], t[j] = t[j], t[i]
  end
end

local function reveal_in_tree()
  state.tvp_tree:open()
  local params = lsp.util.make_position_params()
  state.attatched_bufnr = api.nvim_get_current_buf()

  vim.lsp.buf_request(0, "metals/treeViewReveal", params, function(err, _, res)
    if err then
      log.error_and_show("Unable to execute node command.")
    else
      if res and res.viewId == metals_packages then
        reverse(res.uriChain)

        local head = table.remove(res.uriChain, 1)

        state.tvp_tree:tree_view_children({
          view_id = res.viewId,
          parent_uri = head,
          additionals = res.uriChain,
          expand = true,
        })
        local total = #state.tvp_tree.lookup
        P(total)
      else
        P("idn this shouldn't happen")
      end
    end
  end)
end

return {
  handlers = handlers,
  node_command = node_command,
  reveal_in_tree = reveal_in_tree,
  toggle_tree_view = toggle_tree_view,
  toggle_node = toggle_node,
  debug_tree = function()
    P(state)
  end,
}
