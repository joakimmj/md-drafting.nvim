-- Line- and row-level constructs: quotes, callouts, table rows, code fences,
-- thematic breaks.
local M = {}

--- Quote one line; a blank line becomes a bare "> " rather than ending the quote.
---@param line string Line to quote
---@return string quoted Quoted line
function M.format_quote(line)
  if line:match("^%s*$") then
    return "> "
  end
  return "> " .. line
end

--- A callout is a block quote with a type line on top of it.
---@param callout_type string Callout type, e.g. "NOTE"
---@return string header Callout header line
function M.format_callout(callout_type)
  return "> [!" .. callout_type .. "]"
end

--- One table row from its cells, padded so an empty skeleton still reads as one.
---@param cells string[] Cell contents, one per column
---@return string row Table row
function M.format_table_row(cells)
  local row = "|"
  for _, cell in ipairs(cells) do
    row = row .. " " .. cell .. " |"
  end
  return row
end

--- A fence line, whose info string carries the language and nothing else.
---@param lang? string Language, omitted for a closing fence
---@return string fence Fence line
function M.format_code_fence(lang)
  return "```" .. (lang or "")
end

--- The character a thematic break is drawn with, or nil when the line is not one.
---@param line string Line to read
---@return string? char Break character, one of "-", "*" or "_"
function M.parse_thematic_break(line)
  return line:match("^%s*([%-%*%_])%s*%1%s*%1%s*%s*$")
end

return M
