-- Links, images, and the reference-style forms of both.
local M = {}

--- Format an inline link.
---@param text string Link text
---@param path string Destination, a path or a URL
---@return string link Inline link
function M.format_link(text, path)
  return "[" .. text .. "](" .. path .. ")"
end

--- An image is a link with a "!" in front of it.
---@param alt string Alt text
---@param path string Image source, a path or a URL
---@return string image Inline image
function M.format_image(alt, path)
  return "!" .. M.format_link(alt, path)
end

--- Format a reference-style link, which carries a label, not a destination.
---@param text string Link text
---@param ref string Reference name
---@return string link Reference-style link
function M.format_reference_link(text, ref)
  return "[" .. text .. "][" .. ref .. "]"
end

--- The label a reference-style link is looked up by.
---@param ref string Reference name
---@return string label Bracketed label
function M.format_link_label(ref)
  return "[" .. ref .. "]"
end

--- The definition that gives a label its destination.
---@param ref string Reference name
---@param url string Destination
---@return string definition Definition line
function M.format_reference_definition(ref, url)
  return M.format_link_label(ref) .. ": " .. url
end

return M
