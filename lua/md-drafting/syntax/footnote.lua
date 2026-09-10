-- Footnotes: the reference left in the prose, and the definition it points at.
local M = {}

--- Format a footnote reference.
---@param number integer Footnote number
---@return string ref Reference as written in the prose
function M.format_footnote_ref(number)
  return "[^" .. number .. "]"
end

--- Format the definition a reference points at.
---@param number integer Footnote number
---@param text string Footnote text
---@return string definition Definition line
function M.format_footnote_definition(number, text)
  return M.format_footnote_ref(number) .. ": " .. text
end

--- Every footnote in a string, references and definitions alike.
---
--- Each match carries the column its "[" sits at, so a caller moving the cursor
--- to a footnote has somewhere to land.
---@param content string Text to scan
---@return { n: integer, col: integer }[] footnotes Footnotes, in the order they appear
function M.parse_footnote_refs(content)
  local footnotes = {}
  local at = 1

  while true do
    local start_col, end_col, digits = content:find("%[%^([%d]+)%]", at)
    if not start_col then
      return footnotes
    end

    table.insert(footnotes, { n = tonumber(digits), col = start_col - 1 })
    at = end_col + 1
  end
end

return M
