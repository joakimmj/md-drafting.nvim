-- Fenced sections: a named section between an HTML comment pair.
local M = {}

local text_util = require("md-drafting.lib.text")

--- The comment a section opens with.
---@param name string Section name
---@return string marker Open marker
local function open_marker(name)
  return "<!-- " .. name .. " -->"
end

--- The comment a section closes with.
---@param name string Section name
---@return string marker Close marker
local function close_marker(name)
  return "<!-- /" .. name .. " -->"
end

--- Find a fenced section
---@param lines string[] Text lines
---@param name string Section name
---@return integer? start_row 1-indexed start row, or nil when there is no section
---@return integer? end_row 1-indexed end row
local function find(lines, name)
  local open, close = open_marker(name), close_marker(name)
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

--- The lines between the markers. An empty section is an empty list, which is
--- not the same answer as there being no section at all.
---@param lines string[] Text lines
---@param name string Section name
---@return string[]? body Body text, or nil when there is no section
function M.get(lines, name)
  local start_row, end_row = find(lines, name)
  if not start_row or not end_row then
    return nil
  end

  local body = {}
  for row = start_row + 1, end_row - 1 do
    table.insert(body, lines[row])
  end
  return body
end

--- Create fenced section
---@param name string Section name
---@param body string[] Body text
---@return string[] fenced_section Fenced section with body
local function block(name, body)
  local result = { open_marker(name) }
  for _, line in ipairs(body) do
    table.insert(result, line)
  end
  table.insert(result, close_marker(name))
  return result
end

--- Write a replacement over an inclusive 1-indexed range of lines. An empty
--- range (last < first) is a pure insertion.
---@param lines string[] Text lines
---@param first integer 1-indexed start row
---@param last integer 1-indexed end row
---@param replacement string[] Lines to write over the range
---@return string[] lines Rewritten text lines
local function apply(lines, first, last, replacement)
  local result = {}
  for row = 1, first - 1 do
    table.insert(result, lines[row])
  end
  for _, line in ipairs(replacement) do
    table.insert(result, line)
  end
  for row = last + 1, #lines do
    table.insert(result, lines[row])
  end
  return result
end

--- Replace the section's contents wholesale, writing the section itself when
--- the lines do not have one yet. Safe to re-run: the result depends only on
--- `body`, never on what was there before.
---@param lines string[] Text lines
---@param name string Section name
---@param body string[] Body text
---@param opts? table Options
---@return string[] lines Rewritten text lines
function M.set(lines, name, body, opts)
  local start_row, end_row = find(lines, name)
  if start_row and end_row then
    return apply(lines, start_row, end_row, block(name, body))
  end

  local row = opts and opts.at or #lines + 1
  return apply(lines, row, row - 1, block(name, body))
end

return M
