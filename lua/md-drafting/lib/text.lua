-- String handling that is not markdown
local M = {}

--- Strip leading and trailing whitespace.
---@param text string Text to trim
---@return string trimmed Text without surrounding whitespace
function M.trim(text)
  return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

return M
