-- Assertions over the parts of the plugin that need no window and no cursor.
-- Run from the repository root:
--
--   nvim -l tests/run.lua

package.path = "lua/?.lua;lua/?/init.lua;" .. package.path

local focused_view = require("md-drafting.lib.focused_view")
local section = require("md-drafting.lib.section")
local syntax = require("md-drafting.syntax")
local text = require("md-drafting.lib.text")

local failures = 0
local checks = 0

local function render(value)
  if type(value) ~= "table" then
    return tostring(value)
  end

  local parts = {}
  for key, item in pairs(value) do
    table.insert(parts, ("%s = %s"):format(tostring(key), render(item)))
  end
  table.sort(parts)
  return "{ " .. table.concat(parts, ", ") .. " }"
end

local function same(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then
    return a == b
  end

  for key, value in pairs(a) do
    if not same(value, b[key]) then
      return false
    end
  end
  for key in pairs(b) do
    if a[key] == nil then
      return false
    end
  end
  return true
end

local function check(name, actual, expected)
  checks = checks + 1
  if same(actual, expected) then
    return
  end

  failures = failures + 1
  io.stderr:write(("FAIL  %s\n  expected: %s\n  actual:   %s\n"):format(name, render(expected), render(actual)))
end

-- lib: text

check("trim", text.trim("  padded  "), "padded")
check("trim, nothing to strip", text.trim("bare"), "bare")
check("trim, all whitespace", text.trim("   "), "")

-- syntax: every construct file is flattened onto the module

for _, path in ipairs(vim.fn.glob("lua/md-drafting/syntax/*.lua", false, true)) do
  local construct = path:match("([^/]+)%.lua$")
  if construct ~= "init" then
    for name, value in pairs(require("md-drafting.syntax." .. construct)) do
      check(("syntax.%s, from %s.lua"):format(name, construct), syntax[name], value)
    end
  end
end

-- syntax: links

check("format_link", syntax.format_link("Note", "note.md"), "[Note](note.md)")
check("format_link with anchor", syntax.format_link("A heading", "#a-heading"), "[A heading](#a-heading)")
check("format_image", syntax.format_image("Diagram", "assets/d.png"), "![Diagram](assets/d.png)")
check("format_reference_link", syntax.format_reference_link("docs", "nvim"), "[docs][nvim]")
check("format_link_label", syntax.format_link_label("nvim"), "[nvim]")
check(
  "format_reference_definition",
  syntax.format_reference_definition("nvim", "https://neovim.io"),
  "[nvim]: https://neovim.io"
)
check("parse_links, none", syntax.parse_links("plain prose"), {})
check("parse_links, one", syntax.parse_links("see [Note](note.md)"), { { text = "Note", path = "note.md", col = 4 } })
check("parse_links, several", syntax.parse_links("[a](one.md) and [b](two.md)"), {
  { text = "a", path = "one.md", col = 0 },
  { text = "b", path = "two.md", col = 16 },
})
check("parse_links, an image is skipped", syntax.parse_links("![Diagram](d.png)"), {})
check(
  "parse_links, a link beside an image",
  syntax.parse_links("![Diagram](d.png) [Note](note.md)"),
  { { text = "Note", path = "note.md", col = 18 } }
)
check("parse_links, empty text", syntax.parse_links("[](note.md)"), { { text = "", path = "note.md", col = 0 } })
check("parse_links, a reference-style link is not one", syntax.parse_links("[text][ref]"), {})
check("parse_reference_links, none", syntax.parse_reference_links("plain prose"), {})
check("parse_reference_links, one", syntax.parse_reference_links("see [docs][nvim]"), {
  { text = "docs", ref = "nvim", col = 4 },
})
check("parse_reference_links, an inline link is not one", syntax.parse_reference_links("[Note](note.md)"), {})
check("parse_reference_links, collapsed", syntax.parse_reference_links("[nvim][]"), {
  { text = "nvim", ref = "", col = 0 },
})
check("parse_reference_links, an image is skipped", syntax.parse_reference_links("![Diagram][d]"), {})
check("parse_reference_links, a definition is not one", syntax.parse_reference_links("[nvim]: https://neovim.io"), {})

-- syntax: list items

local function list_item(line)
  local prefix, marker, text_after = syntax.parse_list_item(line)
  return { prefix = prefix, marker = marker, text = text_after }
end

check("parse_list_item, not a list", list_item("plain prose"), { prefix = nil, marker = nil, text = nil })
check("parse_list_item, plain", list_item("- write it up"), { prefix = "- ", marker = nil, text = "write it up" })
check("parse_list_item, indented", list_item("    * nested"), { prefix = "    * ", marker = nil, text = "nested" })
check("parse_list_item, ordered", list_item("1. first"), { prefix = "1. ", marker = nil, text = "first" })
check("parse_list_item, ordered paren", list_item("2) second"), { prefix = "2) ", marker = nil, text = "second" })
check("parse_list_item, ordered checkbox", list_item("1. [ ] task"), { prefix = "1. ", marker = "[ ]", text = "task" })
check("parse_list_item, checkbox", list_item("- [x] done"), { prefix = "- ", marker = "[x]", text = "done" })
check("parse_list_item, empty checkbox", list_item("- [ ]"), { prefix = "- ", marker = "[ ]", text = "" })
check("parse_list_item, invented marker", list_item("+ [~] maybe"), { prefix = "+ ", marker = "[~]", text = "maybe" })
check(
  "parse_list_item, leading link is not a marker",
  list_item("- [Note](note.md) matters"),
  { prefix = "- ", marker = nil, text = "[Note](note.md) matters" }
)

check("format_list_item, with a marker", syntax.format_list_item("- ", "[x]", "done"), "- [x] done")
check("format_list_item, without one", syntax.format_list_item("- ", nil, "done"), "- done")
check("format_list_item, indented", syntax.format_list_item("  - ", "[ ]", "later"), "  - [ ] later")
check("format_list_item, empty marker keeps no space", syntax.format_list_item("- ", "[ ]", ""), "- [ ]")

for _, line in ipairs({ "- [x] done", "  * plain", "+ [~] maybe", "- [ ]", "1. first", "3) [x] shipped" }) do
  local name = "format_list_item inverts parse_list_item: " .. line
  check(name, syntax.format_list_item(syntax.parse_list_item(line)), line)
end

check("parse_checkbox, not a list item", syntax.parse_checkbox("plain prose"), nil)
check("parse_checkbox, a plain list item", syntax.parse_checkbox("- write it up"), nil)
check("parse_checkbox, open", syntax.parse_checkbox("- [ ] write it up"), "open")
check("parse_checkbox, done", syntax.parse_checkbox("- [x] written"), "done")
check("parse_checkbox, done uppercase", syntax.parse_checkbox("- [X] written"), "done")
check("parse_checkbox, an unknown marker", syntax.parse_checkbox("- [~] halfway"), nil)
check("parse_checkbox, a link is not a marker", syntax.parse_checkbox("- [Note](note.md) matters"), nil)
check("parse_checkbox, replaced markers", syntax.parse_checkbox("- [~] halfway", { open = { "[~]" } }), "open")
check("parse_checkbox, replaced markers drop the default", syntax.parse_checkbox("- [ ] task", { open = { "[~]" } }), nil)

-- syntax: headings and anchors

local function heading(line)
  local level, heading_text = syntax.parse_heading(line)
  return { level = level, text = heading_text }
end

check("parse_heading, level one", heading("# Title"), { level = 1, text = "Title" })
check("parse_heading, level three", heading("###   Setup  "), { level = 3, text = "Setup" })
check("parse_heading, level six", heading("###### Deep"), { level = 6, text = "Deep" })
check("parse_heading, empty", heading("##"), { level = 2, text = "" })
check("parse_heading, not a heading", heading("prose"), { level = nil, text = nil })
check("parse_heading, hashtag is a word", heading("#hashtag"), { level = nil, text = nil })
check("parse_heading, past level six", heading("####### too deep"), { level = nil, text = nil })

check("format_anchor", syntax.format_anchor("A heading"), "#a-heading")
check("format_anchor, punctuation dropped", syntax.format_anchor("What's new?"), "#whats-new")
check("format_anchor, underscores kept", syntax.format_anchor("snake_case name"), "#snake_case-name")

-- syntax: quotes and callouts

check("format_quote", syntax.format_quote("one"), "> one")
check("format_quote, blank line", syntax.format_quote("   "), "> ")
check("format_quote, nests", syntax.format_quote("> already"), "> > already")
check("format_callout", syntax.format_callout("NOTE"), "> [!NOTE]")

-- syntax: footnotes

check("format_footnote_ref", syntax.format_footnote_ref(3), "[^3]")
check("format_footnote_definition", syntax.format_footnote_definition(3, "a source"), "[^3]: a source")
check("parse_footnote_refs, none", syntax.parse_footnote_refs("plain prose"), {})
check(
  "parse_footnote_refs, several",
  syntax.parse_footnote_refs("a[^1] b[^12] c"),
  { { n = 1, col = 1 }, { n = 12, col = 7 } }
)
check("parse_footnote_refs, a definition", syntax.parse_footnote_refs("[^4]: a source"), { { n = 4, col = 0 } })

-- syntax: tables

check("format_table_row", syntax.format_table_row({ "a", "b" }), "| a | b |")
check("format_table_row, blank cells", syntax.format_table_row({ "", "" }), "|  |  |")
check("format_table_row, delimiter", syntax.format_table_row({ "---", "---" }), "| --- | --- |")
check("format_table_row, no cells", syntax.format_table_row({}), "|")

-- syntax: code fences

check("format_code_fence, with a language", syntax.format_code_fence("lua"), "```lua")
check("format_code_fence, without one", syntax.format_code_fence(), "```")

-- syntax: thematic breaks

check("parse_thematic_break, hyphens", syntax.parse_thematic_break("---"), "-")
check("parse_thematic_break, asterisks", syntax.parse_thematic_break("***"), "*")
check("parse_thematic_break, underscores", syntax.parse_thematic_break("  ___  "), "_")
check("parse_thematic_break, spaced out", syntax.parse_thematic_break("- - -"), "-")
check("parse_thematic_break, mixed is not one", syntax.parse_thematic_break("--*"), nil)
check("parse_thematic_break, too short", syntax.parse_thematic_break("--"), nil)
check("parse_thematic_break, a list item is not one", syntax.parse_thematic_break("- item"), nil)

-- syntax: emphasis, one case per EMPHASIS marker

check("format_emphasis, bold", syntax.format_emphasis("word", syntax.EMPHASIS.bold), "**word**")
check("format_emphasis, italic", syntax.format_emphasis("word", syntax.EMPHASIS.italic), "*word*")
check("format_emphasis, strikethrough", syntax.format_emphasis("word", syntax.EMPHASIS.strikethrough), "~~word~~")
check("format_emphasis, inline code", syntax.format_emphasis("word", syntax.EMPHASIS.code), "`word`")
check("format_emphasis, empty pair", syntax.format_emphasis("", syntax.EMPHASIS.code), "``")

-- syntax: frontmatter

local function frontmatter(lines)
  local fields, end_row = syntax.parse_frontmatter(lines)
  return { fields = fields, end_row = end_row }
end

check("parse_frontmatter, none", frontmatter({ "# Title" }), { fields = nil, end_row = nil })
check("parse_frontmatter, unterminated", frontmatter({ "---", "title: A note" }), { fields = nil, end_row = nil })
check("parse_frontmatter, scalars", frontmatter({
  "---",
  "header_left: My Talk",
  "header_center: Introduction",
  "---",
  "# First slide",
}), {
  fields = { header_left = "My Talk", header_center = "Introduction" },
  end_row = 4,
})
check("parse_frontmatter, lists", frontmatter({
  "---",
  "tags:",
  "  - java",
  "  - nvim",
  "participants:",
  "  - Alice Smith",
  "---",
}), {
  fields = { tags = { "java", "nvim" }, participants = { "Alice Smith" } },
  end_row = 7,
})
check("parse_frontmatter, empty value", frontmatter({ "---", "tags:", "---" }), {
  fields = { tags = "" },
  end_row = 3,
})
check("parse_frontmatter, empty block", frontmatter({ "---", "---" }), { fields = {}, end_row = 2 })

-- section: markers

check("open_marker", section.open_marker("TOC"), "<!-- TOC -->")
check("close_marker", section.close_marker("TOC"), "<!-- /TOC -->")

-- section: find

local document = {
  "# Title",
  "<!-- TOC -->",
  "- [Title](#title)",
  "<!-- /TOC -->",
  "",
  "Prose.",
}

check("find, present", { section.find(document, "TOC") }, { 2, 4 })
check("find, absent", { section.find(document, "SYNAPSES") }, {})
check("find, opening marker alone", { section.find({ "<!-- TOC -->", "text" }, "TOC") }, {})
check("find, closing marker alone", { section.find({ "text", "<!-- /TOC -->" }, "TOC") }, {})
check("find, indented markers", { section.find({ "  <!-- TOC -->", "  <!-- /TOC -->" }, "TOC") }, { 1, 2 })

-- section: regenerate, the one part that needs a buffer

local function regenerate(lines, body, opts)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  section.regenerate(bufnr, "TOC", body, opts)
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

check("regenerate, replaces an existing section", regenerate(document, { "- [New](#new)" }), {
  "# Title",
  "<!-- TOC -->",
  "- [New](#new)",
  "<!-- /TOC -->",
  "",
  "Prose.",
})
check("regenerate, at the given row", regenerate({ "# Title", "Prose." }, { "- [Title](#title)" }, { at = 2 }), {
  "# Title",
  "<!-- TOC -->",
  "- [Title](#title)",
  "<!-- /TOC -->",
  "Prose.",
})
check("regenerate, appends without a row", regenerate({ "# Title" }, { "- [Title](#title)" }), {
  "# Title",
  "<!-- TOC -->",
  "- [Title](#title)",
  "<!-- /TOC -->",
})
check("regenerate, empty body", regenerate({ "# Title" }, {}), { "# Title", "<!-- TOC -->", "<!-- /TOC -->" })
check("regenerate, an existing section ignores at", regenerate(document, { "- [New](#new)" }, { at = 1 }), {
  "# Title",
  "<!-- TOC -->",
  "- [New](#new)",
  "<!-- /TOC -->",
  "",
  "Prose.",
})

-- lib: focused_view header

local header_line = focused_view.header_line

check("header_line, a section given as a string", header_line({ left = "note.md" }), " note.md%=%= ")
check(
  "header_line, every section",
  header_line({ left = "My Talk", center = "Introduction", right = "1/7" }),
  " My Talk%=Introduction%=1/7 "
)
check("header_line, nothing given", header_line({}), " %=%= ")
check(
  "header_line, a section with a highlight group",
  header_line({ right = { text = "12 lines", hl = "Comment" } }),
  " %=%=%#Comment#12 lines%* "
)
-- Winbar content is parsed as a statusline, so text out of the document has to
-- come back escaped rather than read as an item.
check("header_line, percent escaped", header_line({ left = "100% done" }), " 100%% done%=%= ")

if failures > 0 then
  io.stderr:write(("\n%d of %d checks failed\n"):format(failures, checks))
  os.exit(1)
end

print(("%d checks passed"):format(checks))
