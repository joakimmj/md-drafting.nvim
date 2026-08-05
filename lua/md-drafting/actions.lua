local M = {}

---@class RunAction
---@field label string
---@field run fun(opts: table)

---@class PrepareAction
---@field label string
---@field prepare fun(opts: table): fun(opts: table)

---@type (RunAction | PrepareAction)[]
M.actions = {}

function M.register(action)
  table.insert(M.actions, action)
end

function M.open_menu(opts)
  local choices = {}
  for _, action in ipairs(M.actions) do
    table.insert(choices, {
      label = action.label,
      run = action.prepare and action.prepare(opts) or function()
        action.run(opts)
      end,
    })
  end

  vim.ui.select(choices, {
    prompt = "Actions:",
    format_item = function(choice)
      return choice.label
    end,
  }, function(choice)
    if choice then
      choice.run()
    end
  end)
end

return M
