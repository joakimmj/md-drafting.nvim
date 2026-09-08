-- Markdown syntax itself: how each construct is written and read back. Pure
-- string functions, no buffer and no config. One file per construct, flattened
-- onto this table.
local M = {}

for _, construct in ipairs({
  "block",
  "emphasis",
  "footnote",
  "frontmatter",
  "heading",
  "link",
  "list",
}) do
  for name, value in pairs(require("md-drafting.syntax." .. construct)) do
    M[name] = value
  end
end

return M
