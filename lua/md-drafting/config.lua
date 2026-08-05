local M = {}

M.options = {
  -- Add user commands for all functions in the plugin.
  -- default: false
  add_commands = false,

  -- Markers cycled through by `task.toggle`, in order. A plain list item is
  -- not one of them: cycling past the last marker removes it again.
  task_states = { "[ ]", "[x]" },
}

return M
