-- ATX headings, and the anchors they can be linked by.
local M = {}

local text_util = require("md-drafting.lib.text")

--- A heading's depth and text, or nil when the line is not one.
---@param line string Line to read
---@return integer? level Heading depth, 1 to 6, or nil when not a heading
---@return string? text Heading text, trimmed
function M.parse_heading(line)
  local hashes, rest = line:match("^(#+)(.*)$")
  if not hashes or #hashes > 6 then
    return nil
  end
  if rest ~= "" and not rest:match("^%s") then
    return nil
  end
  return #hashes, text_util.trim(rest)
end

--- The in-document anchor a heading can be linked by, following GitHub's slugs.
---@param text string Heading text
---@return string anchor Anchor, including its leading "#"
function M.format_anchor(text)
  return "#" .. (text:gsub("[^%w%s_-]", ""):gsub("%s", "-"):lower())
end

return M
