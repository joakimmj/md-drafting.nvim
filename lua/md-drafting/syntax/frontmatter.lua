-- The block a document may open with, between two "---" lines. Not markdown,
-- but part of how a markdown document is written in practice.
local M = {}

local text_util = require("md-drafting.lib.text")

local QUOTES = { ['"'] = true, ["'"] = true }

-- What a backslash stands for inside double quotes; any other escaped
-- character stands for itself.
local ESCAPES = { n = "\n", t = "\t" }

--- Read a quoted string, the way YAML does: backslash escapes inside double
--- quotes, a doubled quote inside single quotes.
---@param text string Text holding the string
---@param pos integer Position of the opening quote
---@return string? content Text between the quotes, or nil when it is never closed
---@return integer? next_pos Position after the closing quote
local function read_quoted(text, pos)
  local quote = text:sub(pos, pos)
  local parts = {}
  local i = pos + 1

  while i <= #text do
    local char = text:sub(i, i)
    if quote == '"' and char == "\\" and i < #text then
      local escaped = text:sub(i + 1, i + 1)
      table.insert(parts, ESCAPES[escaped] or escaped)
      i = i + 2
    elseif char == quote and quote == "'" and text:sub(i + 1, i + 1) == "'" then
      table.insert(parts, "'")
      i = i + 2
    elseif char == quote then
      return table.concat(parts), i + 1
    else
      table.insert(parts, char)
      i = i + 1
    end
  end
end

--- Read a flow list (`[a, "b", [c]]`), nested to any depth.
---@param text string Text holding the list
---@param pos integer Position of the opening bracket
---@return table? items Items, strings or nested lists
---@return integer? next_pos Position after the closing bracket
---@return string? err Why the list could not be read
---@return boolean? incomplete Whether more text could still close it
local function read_flow_list(text, pos)
  local items = {}
  local i = pos + 1

  while true do
    i = text:find("%S", i)
    if not i then
      return nil, nil, "unclosed flow list", true
    end

    local char = text:sub(i, i)
    if char == "]" then
      return items, i + 1
    elseif char == "," then
      return nil, nil, "unexpected text in flow list"
    elseif char == "[" then
      local nested, next_pos, err, incomplete = read_flow_list(text, i)
      if not nested then
        return nil, nil, err, incomplete
      end
      table.insert(items, nested)
      i = next_pos
    elseif QUOTES[char] then
      local content, next_pos = read_quoted(text, i)
      if not content then
        return nil, nil, "unclosed quote", true
      end
      table.insert(items, content)
      i = next_pos
    else
      local stop = text:find("[,%]]", i)
      if not stop then
        return nil, nil, "unclosed flow list", true
      end
      table.insert(items, text_util.trim(text:sub(i, stop - 1)))
      i = stop
    end

    i = text:find("%S", i)
    if not i then
      return nil, nil, "unclosed flow list", true
    end

    local separator = text:sub(i, i)
    if separator == "]" then
      return items, i + 1
    elseif separator ~= "," then
      return nil, nil, "unexpected text in flow list"
    end
    i = i + 1
  end
end

--- Read one value: a flow list, a quoted string, or plain text.
---@param text string Text holding the value
---@return string|table? value Value, or nil when it could not be read
---@return string? err Why the value could not be read
---@return boolean? incomplete Whether more text could still complete it
local function read_value(text)
  local start = text:find("%S")
  if not start then
    return ""
  end

  local char = text:sub(start, start)
  if char == "[" then
    local items, next_pos, err, incomplete = read_flow_list(text, start)
    if not items then
      return nil, err, incomplete
    elseif text:find("%S", next_pos) then
      return nil, "unexpected text after flow list"
    end
    return items
  elseif QUOTES[char] then
    local content, next_pos = read_quoted(text, start)
    if not content then
      return nil, "unclosed quote", true
    elseif text:find("%S", next_pos) then
      return nil, "unexpected text after quoted value"
    end
    return content
  end

  return text_util.trim(text)
end

--- Read a value that may run past its line, folding each line that follows
--- into a space until it closes, the way YAML does.
---@param lines string[] Text lines
---@param row integer Row the value starts on
---@param text string The value's text on that row
---@return string|table? value Value, or nil when it could not be read
---@return integer? last_row Row the value ends on
---@return string? err Why the value could not be read
local function read_multiline(lines, row, text)
  while true do
    local value, err, incomplete = read_value(text)
    if value then
      return value, row
    end

    row = row + 1
    if not incomplete or row > #lines or text_util.trim(lines[row]) == "---" then
      return nil, nil, err
    end
    text = text .. " " .. text_util.trim(lines[row])
  end
end

--- Read a document's frontmatter: scalars and lists, block or flow, nested to
--- any depth. Values stay strings.
---@param lines string[] Text lines
---@return table<string, string|table>? fields Fields, or nil when there is no frontmatter
---@return integer? end_row 1-indexed row of the closing delimiter
---@return string? err Why the frontmatter could not be read
function M.parse_frontmatter(lines)
  if text_util.trim(lines[1] or "") ~= "---" then
    return nil
  end

  local fields = {}
  local key
  -- The block lists open under `key`, innermost last. `open` marks a list
  -- whose last item is an empty `-`, which deeper items turn into a list.
  local stack = {}

  local function fail(row, reason)
    return nil, nil, ("line %d: %s for '%s'"):format(row, reason, key)
  end

  local row = 2
  while row <= #lines do
    local line = lines[row]
    if text_util.trim(line) == "---" then
      return fields, row
    end

    local indent, item = line:match("^(%s*)%-%s+(.*)$")
    if not indent then
      indent, item = line:match("^(%s*)%-$"), ""
    end

    if indent and key then
      local column = #indent

      if #stack == 0 then
        if fields[key] ~= "" then
          return fail(row, "list item under a value")
        end
        fields[key] = {}
        table.insert(stack, { indent = column, list = fields[key] })
      else
        while #stack > 0 and stack[#stack].indent > column do
          table.remove(stack)
        end

        local top = stack[#stack]
        if top and top.indent < column and top.open then
          local nested = {}
          top.list[#top.list] = nested
          top.open = false
          table.insert(stack, { indent = column, list = nested })
        elseif not top or top.indent ~= column then
          return fail(row, "bad indentation")
        end
      end

      -- A compact nested list, `- - item`, opens a list at each inner dash.
      local frame = stack[#stack]
      local item_column = #line - #item
      while true do
        local inner = item:match("^%-%s+(.*)$") or (item == "-" and "")
        if not inner then
          break
        end

        local nested = {}
        table.insert(frame.list, nested)
        frame.open = false
        frame = { indent = item_column, list = nested }
        table.insert(stack, frame)
        item_column, item = #line - #inner, inner
      end

      if text_util.trim(item) == "" then
        table.insert(frame.list, "")
        frame.open = true
      else
        local value, last_row, err = read_multiline(lines, row, item)
        if err then
          return fail(row, err)
        end
        table.insert(frame.list, value)
        frame.open = false
        row = last_row
      end
    else
      local name, value = line:match("^([^:]+):%s*(.*)$")
      if name then
        key = text_util.trim(name)
        stack = {}

        local result, last_row, err = read_multiline(lines, row, value)
        if err then
          return fail(row, err)
        end
        fields[key] = result
        row = last_row
      end
    end

    row = row + 1
  end
end

return M
