local M = {}

local config = require("md-drafting.config")
local util = require("md-drafting.util")

local LIST_ITEM_PATTERNS = {
  "^%s*[%-%*%+]%s+", -- bullet: -, *, +
  "^%s*%d+[%.%)]%s+", -- ordered: 1. , 1)
}

-- The list marker and its trailing space, or nil when the line is not a list
-- item.
local function list_prefix(line)
  for _, pattern in ipairs(LIST_ITEM_PATTERNS) do
    local prefix = line:match(pattern)
    if prefix then
      return prefix
    end
  end
end

-- Which configured state the body is in, if any. A body with no marker is not
-- a state: it is where the cycle starts and ends.
local function state_of(body, states)
  for i, marker in ipairs(states) do
    if body:sub(1, #marker) == marker then
      return i
    end
  end
end

function M.toggle()
  local bufnr = vim.api.nvim_get_current_buf()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local line = util.line(bufnr, lnum - 1)
  local states = config.options.task_states

  local prefix = list_prefix(line)

  if not prefix then
    vim.notify("Not on a list item.", vim.log.levels.ERROR)
    return
  end

  if #states == 0 then
    return
  end

  local body = line:sub(#prefix + 1)
  local index = state_of(body, states)
  local new_line

  if not index then
    -- Plain list item: take the first state.
    new_line = prefix .. states[1] .. " " .. body
  elseif index < #states then
    new_line = prefix .. states[index + 1] .. body:sub(#states[index] + 1)
  else
    -- Past the last state: back to a plain list item.
    new_line = prefix .. (body:sub(#states[index] + 1):gsub("^%s+", ""))
  end

  if new_line ~= line then
    vim.api.nvim_buf_set_lines(bufnr, lnum - 1, lnum, false, { new_line })
  end
end

return M
