-- List items, and the checkbox a list item may carry.
local M = {}

-- Marker and the space after it, bulleted or ordered.
---@type string[]
local LIST_ITEM_PATTERNS = {
  "^(%s*[%-%*%+]%s+)", -- bullet: -, *, +
  "^(%s*%d+[%.%)]%s+)", -- ordered: 1. , 1)
}

--- The bullet or number a list item opens with, or nil when the line is not one.
---@param line string Line to read
---@return string? prefix Marker and the whitespace around it
local function list_prefix(line)
  for _, pattern in ipairs(LIST_ITEM_PATTERNS) do
    local prefix = line:match(pattern)
    if prefix then
      return prefix
    end
  end
end

--- Split a list item into its prefix, bracketed marker, and the text after both.
---@param line string Line to read
---@return string? prefix Bullet prefix, or nil when not a list item
---@return string? marker Bracketed marker, or nil when the item has none
---@return string? text Text after the prefix and marker
function M.parse_list_item(line)
  local prefix = list_prefix(line)
  if not prefix then
    return nil
  end

  local rest = line:sub(#prefix + 1)
  local marker = rest:match("^(%[[^%]]*%])")
  if not marker then
    return prefix, nil, rest
  end

  local after = rest:sub(#marker + 1)
  if after ~= "" and not after:match("^%s") then
    return prefix, nil, rest
  end

  return prefix, marker, (after:gsub("^%s+", "", 1))
end

--- Put one back together, the exact inverse of parse_list_item.
---@param prefix string Bullet prefix
---@param marker string? Bracketed marker, or nil for a plain list item
---@param text string Text after the prefix and marker
---@return string line List item
function M.format_list_item(prefix, marker, text)
  if not marker then
    return prefix .. text
  elseif text == "" then
    return prefix .. marker
  end
  return prefix .. marker .. " " .. text
end

return M
