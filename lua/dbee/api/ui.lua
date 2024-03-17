---@mod dbee.ref.api.ui Dbee UI API
---@brief [[
---UI API module for nvim dbee.
---
---This module contains functions to operate with UI tiles.
---Functions are prefixed with a ui name:
---- editor
---- result
---- drawer
---- call_log
---
--- Access the module like this:
--->
---require("dbee").api.ui.func()
---<
---@brief ]]

local state = require("dbee.api.state")

local ui = {}

---@divider -
---@tag dbee.ref.api.ui.editor
---@brief [[
---Editor API
---@brief ]]

---Returns true if dbee ui is loaded.
---@return boolean
function ui.is_loaded()
  return state.is_ui_loaded()
end

---Registers an event handler for editor events.
---@param event editor_event_name
---@param listener event_listener
function ui.editor_register_event_listener(event, listener)
  state.editor():register_event_listener(event, listener)
end

--- Search for a note across namespaces.
---@param id note_id
---@return note_details|nil
---@return namespace_id _ namespace of the note
function ui.editor_search_note(id)
  return state.editor():search_note(id)
end

--- Creates a new note in namespace.
--- Errors if id or name is nil or there is a note with the same
--- name in namespace already.
---@param id namespace_id
---@param name string
---@return note_id
function ui.editor_namespace_create_note(id, name)
  return state.editor():namespace_create_note(id, name)
end

--- Get notes of a specified namespace.
---@param id namespace_id
---@return note_details[]
function ui.editor_namespace_get_notes(id)
  return state.editor():namespace_get_notes(id)
end

--- Removes an existing note.
--- Errors if there is no note with provided id in namespace.
---@param id namespace_id
---@param note_id note_id
function ui.editor_namespace_remove_note(id, note_id)
  state.editor():namespace_remove_note(id, note_id)
end

--- Renames an existing note.
--- Errors if no name or id provided, there is no note with provided id or
--- there is already an existing note with the same name in the same namespace.
---@param id note_id
---@param name string new name
function ui.editor_note_rename(id, name)
  state.editor():note_rename(id, name)
end

--- Get details of a current note
---@return note_details|nil
function ui.editor_get_current_note()
  return state.editor():get_current_note()
end

--- Sets note with id as the current note
--- and opens it in the window.
---@param id note_id
function ui.editor_set_current_note(id)
  state.editor():set_current_note(id)
end

--- Open the editor UI.
---@param winid integer
function ui.editor_show(winid)
  state.editor():show(winid)
end

---@divider -
---@tag dbee.ref.api.ui.call_log
---@brief [[
---Call Log API
---@brief ]]

--- Refresh the call log.
function ui.call_log_refresh()
  state.call_log():refresh()
end

--- Open the call log UI.
---@param winid integer
function ui.call_log_show(winid)
  state.call_log():show(winid)
end

---@divider -
---@tag dbee.ref.api.ui.drawer
---@brief [[
---Drawer API
---@brief ]]

--- Refresh the drawer.
function ui.drawer_refresh()
  state.drawer():refresh()
end

--- Open the drawer UI.
---@param winid integer
function ui.drawer_show(winid)
  state.drawer():show(winid)
end

---@divider -
---@tag dbee.ref.api.ui.result
---@brief [[
---Result API
---@brief ]]

--- Sets call's result to Result's buffer.
---@param call CallDetails
function ui.result_set_call(call)
  state.result():set_call(call)
end

--- Gets the currently displayed call.
---@return CallDetails|nil
function ui.result_get_call()
  return state.result():get_call()
end

--- Display the currently selected page in results UI.
function ui.result_page_current()
  state.result():page_current()
end

--- Go to next page in results UI and display it.
function ui.result_page_next()
  state.result():page_next()
end

--- Go to previous page in results UI and display it.
function ui.result_page_prev()
  state.result():page_prev()
end

--- Open the result UI.
---@param winid integer
function ui.result_show(winid)
  state.result():show(winid)
end

return ui
