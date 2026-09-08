local M = {}

---@class RunAction
---@field label string
---@field run fun(opts: table)

---@class PrepareAction
---@field label string
---@field prepare fun(opts: table): fun(opts: table)

---@class ActionMenuItem
---@field menu string The menu it belongs in
---@field action RunAction | PrepareAction

---@type ActionMenuItem[]
M.action_menus = {}

---@param menu string The menu the action belongs in. Register the same action
---again to put it in a second menu: opening both offers it once.
---@param action RunAction | PrepareAction
function M.register(menu, action)
  if type(menu) ~= "string" or menu == "" then
    vim.notify("md-drafting: an action has to be registered to a menu", vim.log.levels.ERROR)
    return
  end

  if type(action) ~= "table" or type(action.label) ~= "string" then
    vim.notify("md-drafting: an action needs a label", vim.log.levels.ERROR)
    return
  end

  if not action.run and not action.prepare then
    vim.notify(("md-drafting: action %q needs either run or prepare"):format(action.label), vim.log.levels.ERROR)
    return
  end

  table.insert(M.action_menus, { menu = menu, action = action })
end

---@return table<string, boolean>
local function known_menus()
  local menus = {}
  for _, item in ipairs(M.action_menus) do
    menus[item.menu] = true
  end
  return menus
end

-- The registered menu names, sorted, for completion.
---@return string[]
function M.menu_names()
  local names = vim.tbl_keys(known_menus())
  table.sort(names)
  return names
end

---@param names string[]
---@return string
local function prompt_for(names)
  if #names == 1 then
    return names[1]:sub(1, 1):upper() .. names[1]:sub(2) .. ":"
  end
  return "Actions:"
end

---@param names string | string[] Menu, or menus, to offer. Several menus are
---shown as one picker, in registration order.
---@param opts? table
function M.open_menu(names, opts)
  if names == nil then
    vim.notify(
      "md-drafting: open_menu needs a menu name, use open_all for every action",
      vim.log.levels.ERROR
    )
    return
  end

  names = type(names) == "string" and { names } or names
  opts = opts or {}

  local known = known_menus()
  local wanted = {}
  for _, name in ipairs(names) do
    if not known[name] then
      vim.notify(("md-drafting: no action menu named %q"):format(name), vim.log.levels.ERROR)
      return
    end
    wanted[name] = true
  end

  -- An action registered to two of the menus asked for is offered once.
  local choices = {}
  local seen = {}
  for _, item in ipairs(M.action_menus) do
    local action = item.action
    if wanted[item.menu] and not seen[action] then
      seen[action] = true
      table.insert(choices, {
        label = action.label,
        run = action.prepare and action.prepare(opts) or function()
          action.run(opts)
        end,
      })
    end
  end

  if vim.tbl_isempty(choices) then
    vim.notify("md-drafting: no actions to choose from", vim.log.levels.WARN)
    return
  end

  vim.ui.select(choices, {
    prompt = prompt_for(names),
    format_item = function(choice)
      return choice.label
    end,
  }, function(choice)
    if choice then
      choice.run()
    end
  end)
end

-- Every action, whichever menu it was registered to.
---@param opts? table
function M.open_all(opts)
  M.open_menu(M.menu_names(), opts)
end

return M
