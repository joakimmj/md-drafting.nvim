-- Emphasis: a run of punctuation on both sides of the text.
local M = {}

-- The markers, named once rather than in each feature that reaches for one.
---@enum EmphasisMarker
M.EMPHASIS = {
  bold = "**",
  italic = "*",
  strikethrough = "~~",
  code = "`",
}

--- Wrap text in an emphasis marker; an empty text gives the bare pair.
---@param text string Text to wrap
---@param marker EmphasisMarker Marker to wrap with, e.g. EMPHASIS.bold
---@return string emphasized Text between the markers
function M.format_emphasis(text, marker)
  return marker .. text .. marker
end

return M
