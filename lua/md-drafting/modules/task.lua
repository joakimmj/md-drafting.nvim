-- Cycling the checkbox on the list item under the cursor.
local M = {}

local config = require("md-drafting.config")
local syntax = require("md-drafting.syntax")
local util = require("md-drafting.lib.util")

--- Where a marker sits in the cycle, or nil when it is not one of them.
---@param marker string? Bracketed marker
---@param cycle string[] Markers in cycling order
---@return integer? index Position in the cycle
local function index_of(marker, cycle)
  for index, candidate in ipairs(cycle) do
    if candidate == marker then
      return index
    end
  end
end

--- Cycle the list item under the cursor: plain, then each configured marker in
--- order, then plain again.
function M.toggle()
  local bufnr = vim.api.nvim_get_current_buf()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local line = util.line(bufnr, lnum - 1)

  local prefix, marker, text = syntax.parse_list_item(line)
  if not prefix then
    vim.notify("md-drafting: not on a list item", vim.log.levels.ERROR)
    return
  end

  local cycle = syntax.marker_cycle(config.options.task_states)
  if #cycle == 0 then
    return
  end

  local index = index_of(marker, cycle)
  local new_line

  if not index then
    -- Plain list item, or a marker nobody configured: take the first state.
    new_line = syntax.format_list_item(prefix, cycle[1], line:sub(#prefix + 1))
  elseif index < #cycle then
    new_line = syntax.format_list_item(prefix, cycle[index + 1], text)
  else
    -- Past the last state: back to a plain list item.
    new_line = syntax.format_list_item(prefix, nil, text)
  end

  if new_line ~= line then
    vim.api.nvim_buf_set_lines(bufnr, lnum - 1, lnum, false, { new_line })
  end
end

return M
