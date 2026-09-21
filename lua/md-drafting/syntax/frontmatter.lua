-- The block a document may open with, between two "---" lines. Not markdown,
-- but part of how a markdown document is written in practice.
local M = {}

local text_util = require("md-drafting.lib.text")

local QUOTES = { ['"'] = true, ["'"] = true }

--- Whether a line is a YAML comment, at any indentation.
---@param line string
---@return boolean
local function is_comment(line)
  return text_util.trim(line):sub(1, 1) == "#"
end

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

---@alias md_drafting.FrontmatterSpans table<string, { first: integer, last: integer, repeated?: boolean }>

--- Read a document's frontmatter: scalars and lists, block or flow, nested to
--- any depth. Values stay strings.
---@param lines string[] Text lines
---@return table<string, string|table>? fields Fields, or nil when there is no frontmatter
---@return integer? end_row 1-indexed row of the closing delimiter
---@return string? err Why the frontmatter could not be read
---@return md_drafting.FrontmatterSpans? spans Rows each field is written on
function M.parse_frontmatter(lines)
  if text_util.trim(lines[1] or "") ~= "---" then
    return nil
  end

  local fields = {}
  local spans = {}
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
      return fields, row, nil, spans
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
      spans[key].last = row
    else
      -- A comment is not a field, whatever it holds. It can only be mistaken
      -- for a key line: a list item starts with "-".
      local name, value = line:match("^([^:]+):%s*(.*)$")
      if name and not is_comment(line) then
        key = text_util.trim(name)
        stack = {}

        local result, last_row, err = read_multiline(lines, row, value)
        if err then
          return fail(row, err)
        end
        fields[key] = result
        -- A key written twice keeps its last value, as `fields` does, and is
        -- marked so a writer knows the earlier one is still there.
        spans[key] = { first = row, last = last_row, repeated = spans[key] ~= nil or nil }
        row = last_row
      end
    end

    row = row + 1
  end
end

-- What a value cannot hold unquoted and still read back as itself: flow-list
-- and mapping punctuation, a comment, a quote, or a line break.
local NEEDS_QUOTES = "[%[%]{},:#\"'\n\t]"

-- Characters a plain value may not start with, since YAML reads them as
-- something other than text.
local INDICATORS = "^[%-?!&*|>%%@`]"

--- Write one value the way parse_frontmatter reads it back: a string as plain
--- text when that is unambiguous and double-quoted otherwise, a list as a flow
--- list.
---@param value string|table String, or a list of values
---@return string text
function M.format_frontmatter_value(value)
  if type(value) == "table" then
    local items = {}
    for _, item in ipairs(value) do
      table.insert(items, M.format_frontmatter_value(item))
    end
    return "[" .. table.concat(items, ", ") .. "]"
  end

  if value ~= "" and value == text_util.trim(value) and not value:find(NEEDS_QUOTES) and not value:find(INDICATORS) then
    return value
  end
  return '"' .. value:gsub('[\\"]', "\\%0"):gsub("\n", "\\n"):gsub("\t", "\\t") .. '"'
end

--- Set one field in a document's frontmatter, keeping every other line as it
--- is. The field's own lines are replaced by one — comments among them kept
--- after it — a new field goes last, and a document without frontmatter gets
--- one. A nil value removes the field; `vim.NIL` writes the bare key, which
--- YAML reads as no value and parse_frontmatter as "". A field written in a
--- shape this cannot rewrite in full is refused rather than left half-replaced.
---@param lines string[] Text lines
---@param name string Field name
---@param value? string|table|userdata New value, nil to remove the field, or vim.NIL for the bare key
---@return string[]? lines New lines, or nil when the field cannot be rewritten
---@return string? err Why not
function M.set_frontmatter_field(lines, name, value)
  local fields, end_row, err, spans = M.parse_frontmatter(lines)
  if err then
    return nil, err
  end

  local result = {}
  for index, line in ipairs(lines) do
    result[index] = line
  end
  local line
  if value == vim.NIL then
    line = name .. ":"
  elseif value ~= nil then
    line = ("%s: %s"):format(name, M.format_frontmatter_value(value --[[@as string|table]]))
  end

  if not fields then
    if line then
      table.insert(result, 1, "---")
      table.insert(result, 2, line)
      table.insert(result, 3, "---")
    end
    return result
  end

  ---@cast spans md_drafting.FrontmatterSpans
  ---@cast end_row integer
  local span = spans[name]
  if not span then
    if line then
      table.insert(result, end_row, line)
    end
    return result
  end

  if span.repeated then
    return nil, ("'%s' is written more than once"):format(name)
  end

  -- Indented lines after the field belong to it, in YAML: a block scalar's
  -- text, a nested mapping. Those are not read, so they would be left behind
  -- under the new value; refuse instead. Comments are not content.
  for row = span.last + 1, end_row - 1 do
    local following = lines[row]
    if following:match("^%S") then
      break
    elseif text_util.trim(following) ~= "" and not is_comment(following) then
      return nil, ("line %d: '%s' continues in a shape that cannot be rewritten"):format(row, name)
    end
  end

  local comments = {}
  for row = span.first, span.last do
    if is_comment(lines[row]) then
      table.insert(comments, lines[row])
    end
  end

  for _ = span.first, span.last do
    table.remove(result, span.first)
  end
  local at = span.first
  if line then
    table.insert(result, at, line)
    at = at + 1
  end
  for index, comment in ipairs(comments) do
    table.insert(result, at + index - 1, comment)
  end
  return result
end

return M
