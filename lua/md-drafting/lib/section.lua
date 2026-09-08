-- Fenced sections: a named section between an HTML comment pair.
local M = {}

local text_util = require("md-drafting.lib.text")

--- The comment a section opens with.
---@param name string Section name
---@return string marker Open marker
function M.open_marker(name)
  return "<!-- " .. name .. " -->"
end

--- The comment a section closes with.
---@param name string Section name
---@return string marker Close marker
function M.close_marker(name)
  return "<!-- /" .. name .. " -->"
end

--- Find a fenced section
---@param lines string[] Text lines
---@param name string Section name
---@return integer? start_row 1-indexed start row, or nil when there is no section
---@return integer? end_row 1-indexed end row
function M.find(lines, name)
  local open, close = M.open_marker(name), M.close_marker(name)
  local start_row

  for row, line in ipairs(lines) do
    local text = text_util.trim(line)
    if not start_row then
      if text == open then
        start_row = row
      end
    elseif text == close then
      return start_row, row
    end
  end

  return nil
end

--- Create fenced section
---@param name string Section name
---@param body string[] Body text
---@return string[] fenced_section Fenced section with body
local function block(name, body)
  local result = { M.open_marker(name) }
  for _, line in ipairs(body) do
    table.insert(result, line)
  end
  table.insert(result, M.close_marker(name))
  return result
end

--- Plan where to put the fenced section (existing location or new)
---@param lines string[] Text lines
---@param name string Section name
---@param body string[] Body text
---@param opts? table Options
---@return integer start_row 1-indexed row number
---@return integer end_row 1-indexed row number
---@return string[] fenced_section Fenced section with body
local function plan(lines, name, body, opts)
  local start_row, end_row = M.find(lines, name)
  if start_row and end_row then
    return start_row, end_row, block(name, body)
  end

  local row = opts and opts.at or #lines + 1
  return row, row - 1, block(name, body)
end

--- Replace/create fenced section
---@param bufnr integer Buffer id, or 0 for current buffer
---@param name string Section name
---@param body string[] Body text
---@param opts? table Options
function M.regenerate(bufnr, name, body, opts)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local first, last, replacement = plan(lines, name, body, opts)
  vim.api.nvim_buf_set_lines(bufnr, first - 1, last, false, replacement)
end

return M
