-- The block a document may open with, between two "---" lines. Not markdown,
-- but part of how a markdown document is written in practice.
local M = {}

local text_util = require("md-drafting.lib.text")

--- Read a document's frontmatter, as scalars and single-level lists.
---@param lines string[] Text lines
---@return table<string, string|string[]>? fields Fields, or nil when there is no frontmatter
---@return integer? end_row 1-indexed row of the closing delimiter
function M.parse_frontmatter(lines)
  if text_util.trim(lines[1] or "") ~= "---" then
    return nil
  end

  local fields = {}
  local key

  for row = 2, #lines do
    local line = lines[row]
    if text_util.trim(line) == "---" then
      return fields, row
    end

    local item = line:match("^%s*%-%s+(.*)$")
    if item and key then
      if type(fields[key]) ~= "table" then
        fields[key] = {}
      end
      table.insert(fields[key], text_util.trim(item))
    else
      local name, value = line:match("^([^:]+):%s*(.*)$")
      if name then
        key = text_util.trim(name)
        fields[key] = text_util.trim(value)
      end
    end
  end
end

return M
