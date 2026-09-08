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

--- Every footnote number in a string, references and definitions alike.
---@param content string Text to scan
---@return integer[] numbers Footnote numbers, in the order they appear
function M.parse_footnote_refs(content)
  local numbers = {}
  for digits in content:gmatch("%[%^([%d]+)%]") do
    table.insert(numbers, tonumber(digits))
  end
  return numbers
end

return M
