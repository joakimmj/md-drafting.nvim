local M = {}

local config = require("md-drafting.config")
local syntax = require("md-drafting.syntax")
local util = require("md-drafting.lib.util")

-- Which configured state a marker is, if any
local function state_of(marker, states)
  for i, state in ipairs(states) do
    if state == marker then
      return i
    end
  end
end

function M.toggle()
  local bufnr = vim.api.nvim_get_current_buf()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local line = util.line(bufnr, lnum - 1)
  local states = config.options.task_states

  local prefix, marker, text = syntax.parse_list_item(line)
  if not prefix then
    vim.notify("Not on a list item.", vim.log.levels.ERROR)
    return
  end

  if #states == 0 then
    return
  end

  local index = marker and state_of(marker, states)
  local new_line

  if not index then
    -- Plain list item: take the first state.
    new_line = syntax.format_list_item(prefix, states[1], line:sub(#prefix + 1))
  elseif index < #states then
    new_line = syntax.format_list_item(prefix, states[index + 1], text)
  else
    -- Past the last state: back to a plain list item.
    new_line = syntax.format_list_item(prefix, nil, text)
  end

  if new_line ~= line then
    vim.api.nvim_buf_set_lines(bufnr, lnum - 1, lnum, false, { new_line })
  end
end

return M
