---@alias con { name: string, type: string, url: string, id: integer }

-- Handler is a wrapper around the go code
-- it is the central part of the plugin and manages connections.
-- almost all functions take the connection id as their argument.
---@class Handler
---@field private connections { integer: con } id - connection mapping
---@field private active_connection integer last called connection
---@field private last_id integer last id number
---@field private ui UI
---@field private page_index integer current page
local Handler = {}

---@param opts? { connections: con[], ui: UI }
function Handler:new(opts)
  opts = opts or {}

  local cons = opts.connections or {}

  local connections = {}
  local last_id = 0
  for id, con in ipairs(cons) do
    if not con.url then
      print("url needs to be set!")
      return
    end
    if not con.type then
      print("no type")
      return
    end

    con.name = con.name or "[empty name]"
    con.id = id

    -- register in go
    vim.fn.Dbee_register_client(tostring(id), con.url, con.type)

    connections[id] = con
    last_id = id
  end

  -- class object
  local o = {
    connections = connections,
    ui = opts.ui,
    last_id = last_id,
    active_connection = 1,
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

---@param connection con
function Handler:add_connection(connection)
  if not connection.url then
    print("url needs to be set!")
    return
  end
  if not connection.type then
    print("no type")
    return
  end

  local name = connection.name or "[empty name]"

  for _, con in pairs(self.connections) do
    if con.name == name then
      return
    end
  end

  self.last_id = self.last_id + 1
  connection.id = self.last_id

  -- register in go
  vim.fn.Dbee_register_client(tostring(self.last_id), connection.url, connection.type)

  self.connections[self.last_id] = connection
end

---@param id integer connection id
function Handler:set_active(id)
  if not id or self.connections[id] == nil then
    print("no id specified!")
    return
  end
  self.active_connection = id
end

---@return con[] list of connections
function Handler:list_connections()
  local cons = {}
  for _, con in pairs(self.connections) do
    table.insert(cons, con)
  end
  return cons
end

---@return con
---@param id? integer connection id
function Handler:connection_details(id)
  id = id or self.active_connection
  return self.connections[id]
end

---@param query string query to execute
---@param id? integer connection id
function Handler:execute(query, id)
  id = id or self.active_connection

  -- call Go function here
  vim.fn.Dbee_execute(tostring(id), query)

  -- open the first page
  self.page_index = 0
  local bufnr = self.ui:open()
  vim.fn.Dbee_display(tostring(id), tostring(self.page_index), tostring(bufnr))
end

---@param id? integer connection id
function Handler:page_next(id)
  id = id or self.active_connection

  -- open ui
  local bufnr = self.ui:open()

  -- go func returns selected page
  self.page_index = vim.fn.Dbee_display(tostring(id), tostring(self.page_index + 1), tostring(bufnr))
end

---@param id? integer connection id
function Handler:page_prev(id)
  id = id or self.active_connection

  -- open ui
  local bufnr = self.ui:open()

  self.page_index = vim.fn.Dbee_display(tostring(id), tostring(self.page_index - 1), tostring(bufnr))
end

---@param history_id string history id
---@param id? integer connection id
function Handler:history(history_id, id)
  id = id or self.active_connection
  -- call Go function here
  vim.fn.Dbee_history(tostring(id), history_id)

  -- open the first page
  self.page_index = 0
  local bufnr = self.ui:open()
  vim.fn.Dbee_display(tostring(id), tostring(self.page_index), tostring(bufnr))
end

---@param id? integer connection id
function Handler:list_history(id)
  id = id or self.active_connection

  local h = vim.fn.Dbee_list_history(tostring(id))
  if not h or h == vim.NIL then
    return {}
  end
  return h
end

---@param id? integer connection id
---@return schemas
function Handler:schemas(id)
  id = id or self.active_connection
  return vim.fn.Dbee_get_schema(tostring(id))
end

---@param format "csv"|"json" how to format the result
---@param file string file to write to
---@param id? integer connection id
function Handler:save(format, file, id)
  id = id or self.active_connection
  -- TODO
  -- open ui
  local bufnr = self.ui:open()
  vim.fn.Dbee_write(tostring(id), tostring(bufnr))
end

return Handler
