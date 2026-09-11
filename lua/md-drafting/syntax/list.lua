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

--- The states a checkbox marker can be in, in cycling order.
---@type string[]
M.TASK_STATES = { "not_done", "done" }

--- Markers a caller that configures none is read against (GitHub Flavored).
---@type { not_done: string[], done: string[] }
local DEFAULT_MARKERS = {
  not_done = { "[ ]" },
  done = { "[x]", "[X]" },
}

--- Which state a bracketed marker belongs to, or nil when it is none of them.
---@param marker string? Bracketed marker, as parse_list_item returns it
---@param markers? { not_done: string[], done: string[] } Markers per state
---@return "not_done"|"done"|nil state Marker state, or nil when unrecognized
function M.marker_state(marker, markers)
  if not marker then
    return nil
  end

  markers = markers or DEFAULT_MARKERS

  for _, state in ipairs(M.TASK_STATES) do
    for _, candidate in ipairs(markers[state] or {}) do
      if candidate == marker then
        return state
      end
    end
  end
end

--- Which state a list item's checkbox is in, or nil when it carries none.
---@param line string Line to read
---@param markers? { not_done: string[], done: string[] } Markers per state
---@return "not_done"|"done"|nil state Checkbox state, or nil when there is none
function M.parse_checkbox(line, markers)
  local _, marker = M.parse_list_item(line)
  return M.marker_state(marker, markers)
end

--- Every marker, in cycling order: not_done first, then done.
---@param markers? { not_done: string[], done: string[] } Markers per state
---@return string[] cycle Markers in the order a toggle moves through them
function M.marker_cycle(markers)
  markers = markers or DEFAULT_MARKERS

  local cycle = {}
  for _, state in ipairs(M.TASK_STATES) do
    vim.list_extend(cycle, markers[state] or {})
  end
  return cycle
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
