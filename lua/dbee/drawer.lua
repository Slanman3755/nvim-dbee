local NuiTree = require("nui.tree")
local NuiLine = require("nui.line")
local utils = require("dbee.utils")

---@class Candy
---@field icon string
---@field icon_highlight string
---@field text_highlight string

---@class Layout
---@field id string unique identifier
---@field name string display name
---@field type ""|"table"|"history"|"scratch"|"connection"|"database_switch"|"add"|"edit"|"remove"|"help"|"source" type of layout
---@field schema? string parent schema
---@field database? string parent database
---@field pick_title? string if present, it's used as a title for pick list
---@field pick_items? string[]|fun():string[] if present, this is used as a selection list, the selection is passed to the action functions if supported
---@field action_1? fun(cb: fun(), selection?: string) primary action if function takes a second selection parameter, pick_items get picked before the call
---@field action_2? fun(cb: fun(), selection?: string) secondary action if function takes a second selection parameter, pick_items get picked before the call
---@field action_3? fun(cb: fun(), selection?: string) tertiary action if function takes a second selection parameter, pick_items get picked before the call
---@field children? Layout[]|fun():Layout[] child layout nodes
---@field default_expand? Once expand on startup? - basically a bool

-- node is Layout converted to NuiTreeNode
---@class Node: Layout
---@field getter fun():Layout

---@alias drawer_config { disable_candies: boolean, candies: table<string, Candy>, mappings: table<string, mapping>, disable_help: boolean }

---@class Drawer
---@field private ui Ui
---@field private tree? table NuiTree
---@field private handler Handler
---@field private editor Editor
---@field private mappings table<string, mapping>
---@field private candies table<string, Candy> map of eye-candy stuff (icons, highlight)
---@field private disable_help boolean show help or not
local Drawer = {}

---@param ui Ui
---@param handler Handler
---@param editor Editor
---@param opts? drawer_config
---@return Drawer
function Drawer:new(ui, handler, editor, opts)
  opts = opts or {}

  if not ui then
    error("no Ui provided to Drawer")
  end
  if not handler then
    error("no Handler provided to Drawer")
  end
  if not editor then
    error("no Editor provided to Drawer")
  end

  local candies = {}
  if not opts.disable_candies then
    candies = opts.candies or {}
  end

  -- class object
  local o = {
    ui = ui,
    tree = nil,
    handler = handler,
    editor = editor,
    mappings = opts.mappings or {},
    candies = candies,
    disable_help = opts.disable_help or false,
  }
  setmetatable(o, self)
  self.__index = self

  -- set keymaps
  o.ui:set_keymap(o:generate_keymap(opts.mappings))

  return o
end

---@private
---@return table tree
function Drawer:create_tree(bufnr)
  return NuiTree {
    bufnr = bufnr,
    prepare_node = function(node)
      local line = NuiLine()

      line:append(string.rep("  ", node:get_depth() - 1))

      if node:has_children() or node.getter then
        local candy = self.candies["node_closed"] or { icon = ">", icon_highlight = "NonText" }
        if node:is_expanded() then
          candy = self.candies["node_expanded"] or { icon = "v", icon_highlight = "NonText" }
        end
        line:append(candy.icon .. " ", candy.icon_highlight)
      else
        line:append("  ")
      end

      ---@type Candy
      local candy
      -- special icons for nodes without type
      if not node.type or node.type == "" then
        if node:has_children() then
          candy = self.candies["none_dir"]
        else
          candy = self.candies["none"]
        end
      else
        candy = self.candies[node.type] or {}
      end
      candy = candy or {}

      if candy.icon then
        line:append(" " .. candy.icon .. " ", candy.icon_highlight)
      end

      -- apply a special highlight for active connection and active scratchpad
      if self.handler:current_connection():details().id == node.id or self.editor:get_active_scratch() == node.id then
        line:append(node.name, candy.icon_highlight)
      else
        line:append(node.name, candy.text_highlight)
      end

      return line
    end,
    get_node_id = function(node)
      if node.id then
        return node.id
      end
      return math.random()
    end,
  }
end

---@private
---@param mappings table<string, mapping>
---@return keymap[]
function Drawer:generate_keymap(mappings)
  mappings = mappings or {}

  local function collapse_node(node)
    if node:collapse() then
      self.tree:render()
    end
  end

  local function expand_node(node)
    -- expand all children nodes with only one field
    local function expand_all_single(n)
      local children = n:get_child_ids()
      if #children == 1 then
        local nested_node = self.tree:get_node(children[1])
        nested_node:expand()
        expand_all_single(nested_node)
      end
    end

    local expanded = node:is_expanded()

    expand_all_single(node)

    -- if function for getting layout exist, call it
    if not expanded and type(node.getter) == "function" then
      node.getter()
    end

    node:expand()

    self.tree:render()
  end

  -- wrapper for actions (e.g. action_1, action_2, action_3)
  ---@param node Node
  ---@param func fun(cb: fun(), selection?: string)
  local function perform_action(node, func)
    if type(func) ~= "function" then
      return
    end

    -- if pick_items field is present, and the function takes an extra arg,
    -- show the menu and then trigger the function with it
    if node.pick_items and utils.get_function_param_number(func) > 1 then
      local pick_items = node.pick_items
      if type(node.pick_items) == "function" then
        pick_items = node.pick_items()
      end

      utils.menu.open(self.ui:window(), pick_items --[[@as string[] ]], function(selection)
        func(function()
          self:refresh()
        end, selection)
      end, node.pick_title)
    else
      func(function()
        self:refresh()
      end)
    end
  end

  return {
    {
      action = function()
        self:refresh()
      end,
      mapping = mappings["refresh"],
    },
    {
      action = function()
        local node = self.tree:get_node()
        if not node then
          return
        end
        perform_action(node, node.action_1)
      end,
      mapping = mappings["action_1"],
    },
    {
      action = function()
        local node = self.tree:get_node()
        if not node then
          return
        end
        perform_action(node, node.action_2)
      end,
      mapping = mappings["action_2"],
    },
    {
      action = function()
        local node = self.tree:get_node()
        if not node then
          return
        end
        perform_action(node, node.action_3)
      end,
      mapping = mappings["action_3"],
    },
    {
      action = function()
        local node = self.tree:get_node()
        if not node then
          return
        end
        collapse_node(node)
      end,
      mapping = mappings["collapse"],
    },
    {
      action = function()
        local node = self.tree:get_node()
        if not node then
          return
        end
        expand_node(node)
      end,
      mapping = mappings["expand"],
    },
    {
      action = function()
        local node = self.tree:get_node()
        if not node then
          return
        end
        if node:is_expanded() then
          collapse_node(node)
        else
          expand_node(node)
        end
      end,
      mapping = mappings["toggle"],
    },
  }
end

-- sets layout to tree
---@private
---@param layout Layout[] layout to add to tree
---@param node_id? string layout is set as children to this id or root
function Drawer:set_layout(layout, node_id)
  --- recursed over Layout[] and sets it to the tree
  ---@param layouts Layout[]
  ---@return Node[] nodes list of NuiTreeNodes
  local function to_node(layouts)
    if not layouts then
      return {}
    end

    local nodes = {}
    for _, l in ipairs(layouts) do
      -- get children or set getter
      local getter
      local children
      if type(l.children) == "function" then
        getter = function()
          local exists = self.tree:get_node(l.id)
          if exists then
            self.tree:set_nodes(to_node(l.children()), l.id)
          end
        end
      else
        children = l.children
      end

      -- all other fields stay the same
      local n = vim.fn.copy(l)
      n.name = string.gsub(l.name, "\n", " ")
      n.getter = getter

      -- get existing node from the current tree and check if it is expanded
      local expanded = false
      local ex_node = self.tree:get_node(l.id)
      if (ex_node and ex_node:is_expanded()) or (l.default_expand and l.default_expand:poke()) then
        expanded = true
        -- if getter exists, and node is expanded, we call it
        if getter then
          children = l.children()
        end
      end
      -- recurse children
      local node = NuiTree.Node(n, to_node(children --[[@as Layout[] ]]))
      if expanded then
        node:expand()
      end

      table.insert(nodes, node)
    end

    return nodes
  end

  -- recurse layout
  if self.tree then
    self.tree:set_nodes(to_node(layout), node_id)
  end
end

---@private
---@return Layout
function Drawer:layout_help()
  -- help node
  local help_children = {}
  for act, map in pairs(self.mappings) do
    table.insert(help_children, {
      id = "__help_action_" .. act,
      name = act .. " = " .. map.key .. " (" .. map.mode .. ")",
      type = "",
    })
  end

  table.sort(help_children, function(k1, k2)
    return k1.id < k2.id
  end)

  ---@type Layout
  return {
    id = "__help_layout__",
    name = "help",
    type = "help",
    default_expand = utils.once:new("help_expand_once_id"),
    children = help_children,
  }
end

function Drawer:refresh()
  -- whitespace between nodes
  ---@return Layout
  local separator = function()
    return {
      id = "__separator_layout__" .. tostring(math.random()),
      name = "",
      type = "",
    }
  end

  -- assemble tree layout
  ---@type Layout[]
  local layouts = {}
  for _, ly in ipairs(self.editor:layout()) do
    table.insert(layouts, ly)
  end
  table.insert(layouts, separator())
  for _, ly in ipairs(self.handler:layout()) do
    table.insert(layouts, ly)
  end

  if not self.disable_help then
    table.insert(layouts, separator())
    table.insert(layouts, self:layout_help())
  end

  self:set_layout(layouts)

  if self.tree then
    self.tree:render()
  end
end

-- Show drawer on screen
function Drawer:open()
  local _, bufnr = self.ui:open()

  -- tree
  if not self.tree then
    self.tree = self:create_tree(bufnr)
    self:refresh()
  end

  self.tree.bufnr = bufnr

  self.tree:render()
end

function Drawer:close()
  self.ui:close()
end

return Drawer
