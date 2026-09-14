-- Assertions over the parts of the plugin that need no window and no cursor.
-- Run from the repository root:
--
--   nvim -l tests/run.lua

package.path = "lua/?.lua;lua/?/init.lua;" .. package.path

local config = require("md-drafting.config")
local focused_view = require("md-drafting.lib.focused_view")
local link_providers = require("md-drafting.lib.link_providers")
local section = require("md-drafting.lib.section")
local syntax = require("md-drafting.syntax")
local text = require("md-drafting.lib.text")
local util = require("md-drafting.lib.util")

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
check("parse_checkbox, not done", syntax.parse_checkbox("- [ ] write it up"), "not_done")
check("parse_checkbox, done", syntax.parse_checkbox("- [x] written"), "done")
check("parse_checkbox, done uppercase", syntax.parse_checkbox("- [X] written"), "done")
check("parse_checkbox, an unknown marker", syntax.parse_checkbox("- [~] halfway"), nil)
check("parse_checkbox, a link is not a marker", syntax.parse_checkbox("- [Note](note.md) matters"), nil)

local CONFIGURED = { not_done = { "[ ]", "[/]" }, done = { "[x]" } }

check("parse_checkbox, configured markers", syntax.parse_checkbox("- [/] halfway", CONFIGURED), "not_done")
check(
  "parse_checkbox, configured markers drop the defaults",
  syntax.parse_checkbox("- [X] written", CONFIGURED),
  nil
)

check("marker_state, not a marker", syntax.marker_state(nil), nil)
check("marker_state, not done", syntax.marker_state("[ ]"), "not_done")
check("marker_state, done", syntax.marker_state("[x]"), "done")
check("marker_state, unknown", syntax.marker_state("[~]"), nil)
check("marker_state, configured", syntax.marker_state("[/]", CONFIGURED), "not_done")

check("marker_cycle, defaults", syntax.marker_cycle(), { "[ ]", "[x]", "[X]" })
check("marker_cycle, not done before done", syntax.marker_cycle(CONFIGURED), { "[ ]", "[/]", "[x]" })
check("marker_cycle, one state only", syntax.marker_cycle({ done = { "[x]" } }), { "[x]" })
check("marker_cycle, no markers", syntax.marker_cycle({}), {})

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
  local fields, end_row, err = syntax.parse_frontmatter(lines)
  return { fields = fields, end_row = end_row, err = err }
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

-- frontmatter lists are read the way YAML reads them, with every value a string

check("parse_frontmatter, flow and block lists together", frontmatter({
  "---",
  [[string_value: "[1, 2, 3]"]],
  "flow_style: [",
  [[1, "2", '3', "4, 5", '6, 7, 8',]],
  "9",
  "]",
  "block_style:",
  "- 1",
  [[- "2"]],
  "- '3'",
  [=[- [4, "5, 6", '7, 8, 9']]=],
  "---",
}), {
  fields = {
    string_value = "[1, 2, 3]",
    flow_style = { "1", "2", "3", "4, 5", "6, 7, 8", "9" },
    block_style = { "1", "2", "3", { "4", "5, 6", "7, 8, 9" } },
  },
  end_row = 12,
})
check("parse_frontmatter, flow list on one line", frontmatter({ "---", "tags: [java, nvim]", "---" }), {
  fields = { tags = { "java", "nvim" } },
  end_row = 3,
})
check("parse_frontmatter, flow lists nest", frontmatter({ "---", "a: [1, [2, [3, [4]]]]", "---" }), {
  fields = { a = { "1", { "2", { "3", { "4" } } } } },
  end_row = 3,
})
check("parse_frontmatter, empty flow list and trailing comma", frontmatter({ "---", "a: []", "b: [a, b,]", "---" }), {
  fields = { a = {}, b = { "a", "b" } },
  end_row = 4,
})
check("parse_frontmatter, quoted scalars", frontmatter({ "---", [[a: "A note"]], "b: 'it''s'", "---" }), {
  fields = { a = "A note", b = "it's" },
  end_row = 4,
})
check("parse_frontmatter, escapes in quotes", frontmatter({ "---", [==[a: ["say \"hi\"", 'it''s']]==], "---" }), {
  fields = { a = { 'say "hi"', "it's" } },
  end_row = 3,
})
check("parse_frontmatter, an apostrophe inside plain text", frontmatter({ "---", "a: [it's, fine]", "---" }), {
  fields = { a = { "it's", "fine" } },
  end_row = 3,
})
check("parse_frontmatter, quoted scalar over lines", frontmatter({ "---", [[a: "one]], [[  two"]], "---" }), {
  fields = { a = "one two" },
  end_row = 4,
})
check("parse_frontmatter, block lists nest", frontmatter({
  "---",
  "a:",
  "  - 1",
  "  -",
  "    - 2",
  "    -",
  "      - 3",
  "  - 4",
  "---",
}), {
  fields = { a = { "1", { "2", { "3" } }, "4" } },
  end_row = 9,
})
check("parse_frontmatter, compact nested block list", frontmatter({ "---", "a:", "- - 1", "  - 2", "- 3", "---" }), {
  fields = { a = { { "1", "2" }, "3" } },
  end_row = 6,
})
check("parse_frontmatter, empty block item", frontmatter({ "---", "a:", "- ", "- b", "---" }), {
  fields = { a = { "", "b" } },
  end_row = 5,
})
check("parse_frontmatter, indented block list", frontmatter({ "---", "a:", "    - 1", "    - 2", "---" }), {
  fields = { a = { "1", "2" } },
  end_row = 5,
})
check("parse_frontmatter, flow list in a block item over lines", frontmatter({ "---", "a:", "- [x,", "  y]", "---" }), {
  fields = { a = { { "x", "y" } } },
  end_row = 5,
})

check("parse_frontmatter, text after a flow list", frontmatter({ "---", "a: [Draft] note", "---" }), {
  err = "line 2: unexpected text after flow list for 'a'",
})
check("parse_frontmatter, text after a quoted value", frontmatter({ "---", [[a: "x" y]], "---" }), {
  err = "line 2: unexpected text after quoted value for 'a'",
})
check("parse_frontmatter, text between flow items", frontmatter({ "---", [=[a: ["b" c]]=], "---" }), {
  err = "line 2: unexpected text in flow list for 'a'",
})
check("parse_frontmatter, empty flow item", frontmatter({ "---", "a: [a,,b]", "---" }), {
  err = "line 2: unexpected text in flow list for 'a'",
})
check("parse_frontmatter, unclosed flow list", frontmatter({ "---", "tags: [a,", "b", "---" }), {
  err = "line 2: unclosed flow list for 'tags'",
})
check("parse_frontmatter, unclosed flow list at the end", frontmatter({ "---", "tags: [a," }), {
  err = "line 2: unclosed flow list for 'tags'",
})
check("parse_frontmatter, unclosed quote", frontmatter({ "---", [[a: "one]], "---" }), {
  err = "line 2: unclosed quote for 'a'",
})
check("parse_frontmatter, block item out of line", frontmatter({ "---", "a:", "  - 1", " - 2", "---" }), {
  err = "line 4: bad indentation for 'a'",
})
check("parse_frontmatter, block item left of its list", frontmatter({ "---", "a:", "  - 1", "- 2", "---" }), {
  err = "line 4: bad indentation for 'a'",
})
check("parse_frontmatter, block item under a value", frontmatter({ "---", "a: x", "- y", "---" }), {
  err = "line 3: list item under a value for 'a'",
})

-- section: get

local document = {
  "# Title",
  "<!-- TOC -->",
  "- [Title](#title)",
  "<!-- /TOC -->",
  "",
  "Prose.",
}


check("get, present", section.get(document, "TOC"), { "- [Title](#title)" })
check("get, empty section", section.get({ "<!-- TOC -->", "<!-- /TOC -->" }, "TOC"), {})
check("get, absent", section.get(document, "SYNAPSES"), nil)

-- section: set

check("set, replaces the body", section.set(document, "TOC", { "- [Other](#other)" }), {
  "# Title",
  "<!-- TOC -->",
  "- [Other](#other)",
  "<!-- /TOC -->",
  "",
  "Prose.",
})

check("set, empties the body", section.set(document, "TOC", {}), {
  "# Title",
  "<!-- TOC -->",
  "<!-- /TOC -->",
  "",
  "Prose.",
})

check("set, writes the section at opts.at", section.set({ "# Title", "", "Prose." }, "TOC", {
  "- [Title](#title)",
}, { at = 2 }), {
  "# Title",
  "<!-- TOC -->",
  "- [Title](#title)",
  "<!-- /TOC -->",
  "",
  "Prose.",
})

check("set, writes the section at the end by default", section.set({ "# Title" }, "TOC", {}), {
  "# Title",
  "<!-- TOC -->",
  "<!-- /TOC -->",
})

check(
  "set, is idempotent",
  section.set(section.set(document, "TOC", { "- [A](#a)" }), "TOC", { "- [A](#a)" }),
  section.set(document, "TOC", { "- [A](#a)" })
)

-- section: the pair round-trips, which is what lets a caller edit a body rather
-- than reach for a function per edit.

check("get after set answers with the body it was given", section.get(section.set(document, "TOC", {
  "- [A](#a)",
  "- [B](#b)",
}), "TOC"), { "- [A](#a)", "- [B](#b)" })

local function append(lines, name, line)
  local body = section.get(lines, name) or {}
  body[#body + 1] = line
  return section.set(lines, name, body)
end

check("appending is get, edit, set", append(document, "TOC", "- [B](#b)"), {
  "# Title",
  "<!-- TOC -->",
  "- [Title](#title)",
  "- [B](#b)",
  "<!-- /TOC -->",
  "",
  "Prose.",
})

check("appending writes the section when there is none", append({ "# Title" }, "LOG", "- entry"), {
  "# Title",
  "<!-- LOG -->",
  "- entry",
  "<!-- /LOG -->",
})

-- lib: replace_lines. What it is for is the write it does not make, so the
-- checks are about extmarks and changedtick as much as about the lines.

local probe_ns = vim.api.nvim_create_namespace("md-drafting-tests")

--- Write `lines` into a buffer holding `before`, with an extmark on `mark_row`
--- (0-indexed), and report what moved.
local function replace_lines(before, lines, mark_row)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, before)
  if mark_row then
    vim.api.nvim_buf_set_extmark(bufnr, probe_ns, mark_row, 0, {})
  end

  local tick = vim.api.nvim_buf_get_changedtick(bufnr)
  util.replace_lines(bufnr, lines)

  local marks = vim.api.nvim_buf_get_extmarks(bufnr, probe_ns, 0, -1, {})
  return {
    lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false),
    mark_row = marks[1] and marks[1][2],
    writes = vim.api.nvim_buf_get_changedtick(bufnr) - tick,
  }
end

local before = { "# Title", "<!-- TOC -->", "- [A](#a)", "<!-- /TOC -->", "", "Prose." }
local grown = { "# Title", "<!-- TOC -->", "- [A](#a)", "- [B](#b)", "<!-- /TOC -->", "", "Prose." }

check("replace_lines, the buffer ends up holding the lines", replace_lines(before, grown).lines, grown)

-- An extmark on "Prose." with one line inserted above it belongs one row lower.
-- A whole-buffer write would drag it to the end of the file instead.
check("replace_lines, a mark below the change follows its line", replace_lines(before, grown, 5).mark_row, 6)
check("replace_lines, a mark above the change stays put", replace_lines(before, grown, 0).mark_row, 0)

check("replace_lines, identical lines are not written", replace_lines(before, before, 5).writes, 0)
check("replace_lines, identical lines leave marks alone", replace_lines(before, before, 5).mark_row, 5)

check("replace_lines, a shrinking buffer", replace_lines(grown, before).lines, before)
check("replace_lines, into an empty buffer", replace_lines({ "" }, { "# Title", "Prose." }).lines, {
  "# Title",
  "Prose.",
})
check("replace_lines, emptying a buffer", replace_lines(before, { "" }).lines, { "" })

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

-- lib: the directory a document sits in, which the local-file provider resolves
-- its folder against

local function document_dir(name)
  local bufnr = vim.api.nvim_create_buf(false, true)
  if name ~= "" then
    vim.api.nvim_buf_set_name(bufnr, name)
  end
  return util.document_dir(bufnr)
end

check("document_dir, a named buffer", document_dir("/home/writer/notes/doc.md"), "/home/writer/notes")
check("document_dir, a file at the root", document_dir("/doc.md"), "/")
check("document_dir, an unnamed buffer falls back to the working directory", document_dir(""), vim.fn.getcwd())

-- lib: the path a link is written with

check("relative_path, a file beside the document", util.relative_path("/notes", "/notes/pic.png"), "pic.png")
check("relative_path, a folder below it", util.relative_path("/notes", "/notes/assets/pic.png"), "assets/pic.png")
check("relative_path, one level up", util.relative_path("/notes/daily", "/notes/pic.png"), "../pic.png")
check("relative_path, two levels up", util.relative_path("/a/b/c", "/a/pic.png"), "../../pic.png")
check("relative_path, a sibling folder", util.relative_path("/a/b", "/a/c/pic.png"), "../c/pic.png")
check("relative_path, nothing in common", util.relative_path("/a/b", "/x/pic.png"), "../../x/pic.png")
check("relative_path, the document's own folder", util.relative_path("/a/b", "/a/b"), ".")
check("relative_path, a trailing separator is not a segment", util.relative_path("/notes/", "/notes/pic.png"), "pic.png")

-- lib: link providers. The registry is global, and nothing has required the
-- plugin itself yet, so these three are all that is in it.

local both = { label = "Both" }
local link_only = { label = "Link only", kinds = { "link" } }
local image_only = { label = "Image only", kinds = { "image" } }

for _, provider in ipairs({ both, link_only, image_only }) do
  link_providers.register(provider)
end

local function labels(kind)
  local names = {}
  for _, provider in ipairs(link_providers.for_kind(kind)) do
    table.insert(names, provider.label)
  end
  return names
end

check("for_kind, link", labels("link"), { "Both", "Link only" })
check("for_kind, image", labels("image"), { "Both", "Image only" })
check("for_kind, naming no kinds is offered to any caller", labels("anything"), { "Both" })

-- pick hands the picker labels rather than the providers themselves: a picker
-- backend may read an item table's own fields, and snacks.nvim calls a
-- `resolve` field it finds there.

local original_select = vim.ui.select
local offered, select_calls = nil, 0

---@diagnostic disable-next-line: duplicate-set-field
vim.ui.select = function(items, _, on_choice)
  offered = items
  select_calls = select_calls + 1
  on_choice(items[2], 2)
end

local chosen
link_providers.pick("link", function(provider)
  chosen = provider
end)

check("pick offers labels, not provider tables", offered, { "Both", "Link only" })
check("pick maps the choice back to its provider", chosen == link_only, true)

chosen, select_calls = nil, 0
link_providers.pick("anything", function(provider)
  chosen = provider
end)

check("pick with one provider opens no picker", select_calls, 0)
check("pick with one provider calls back with it", chosen == both, true)

-- A caller naming a provider skips the question entirely.

chosen, select_calls = nil, 0
link_providers.pick("link", function(provider)
  chosen = provider
end, { provider = "Link only" })

check("pick with a named provider opens no picker", select_calls, 0)
check("pick with a named provider calls back with it", chosen == link_only, true)

chosen = nil
link_providers.pick("link", function(provider)
  chosen = provider
end, { provider = both })

check("pick takes the provider itself, not only its label", chosen == both, true)

chosen, select_calls = nil, 0
link_providers.pick("link", function(provider)
  chosen = provider
end, { provider = "Image only" })

check("pick with a provider of another kind falls back to no picker", select_calls, 0)
check("pick with a provider of another kind calls back with nothing", chosen, nil)

chosen = nil
link_providers.pick("link", function(provider)
  chosen = provider
end, { provider = "Nothing registered under this" })

check("pick with an unknown provider calls back with nothing", chosen, nil)

-- Order: whatever `link_providers.order` names leads, the rest keep the order
-- they registered in.

config.options.link_providers.order = { "Link only" }
check("for_kind, a named provider leads", labels("link"), { "Link only", "Both" })

config.options.link_providers.order = { "Image only", "Both" }
check("for_kind, a name matching nothing for the kind is skipped", labels("link"), { "Both", "Link only" })
check("for_kind, the rest follow in registration order", labels("image"), { "Image only", "Both" })

config.options.link_providers.order = {}
check("for_kind, no order named is registration order", labels("link"), { "Both", "Link only" })

vim.ui.select = original_select

-- api: the dependent-plugin surface is the same code the plugin runs on

local api = require("md-drafting").api

check("api.syntax is the syntax module", api.syntax == syntax, true)
check("api.section.get is the section module's", api.section.get == section.get, true)
check("api.section.set is the section module's", api.section.set == section.set, true)

-- The seam and the module are the same two functions now, which is worth holding
-- in place: everything else the markers need is local to the file.
local function sorted_keys(t)
  local keys = vim.tbl_keys(t)
  table.sort(keys)
  return keys
end

check("api.section is get and set alone", sorted_keys(api.section), { "get", "set" })
check("the section module is the same two", sorted_keys(section), { "get", "set" })
check("api.register_link_provider registers", api.register_link_provider == link_providers.register, true)

-- lib: the file browser, and the built-in provider that walks it. Requiring the
-- plugin above registered "File or URL", so the callers below name it rather
-- than meeting a provider picker that now has something to pick from.

local file_browser = require("md-drafting.lib.file_browser")

local root = vim.fs.normalize(vim.fn.tempname())
vim.fn.mkdir(root .. "/assets", "p")
vim.fn.mkdir(root .. "/.hidden", "p")
vim.fn.writefile({ "" }, root .. "/assets/cat.png")
vim.fn.writefile({ "" }, root .. "/note.md")
vim.fn.writefile({ "" }, root .. "/pic.png")
vim.fn.writefile({ "" }, root .. "/.secret.md")

-- Every list the browser offered, and the labels to choose from them in turn.
-- A label that is not on offer, or a script that has run out, abandons the
-- picker, which is what a user pressing escape does.
local offered, script = {}, {}

---@diagnostic disable-next-line: duplicate-set-field
vim.ui.select = function(items, _, on_choice)
  table.insert(offered, items)

  local wanted = table.remove(script, 1)
  for idx, item in ipairs(items) do
    if item == wanted then
      return on_choice(item, idx)
    end
  end

  on_choice(nil)
end

-- What was asked for, and what to answer with. A prompt past the end of the
-- answers is abandoned, which is what escaping one does.
local answers, prompts = {}, {}

---@diagnostic disable-next-line: duplicate-set-field
util.prompt = function(message)
  table.insert(prompts, message)
  return table.remove(answers, 1)
end

--- Browse from a clean slate, answering with what the browser did.
local function browse(opts, choices, typed)
  offered, script, answers, prompts = {}, vim.deepcopy(choices), vim.deepcopy(typed or {}), {}

  local answer
  file_browser.browse(vim.tbl_extend("force", { dir = root, typed_prompt = "Enter URL" }, opts), function(result)
    answer = result
  end)

  return answer
end

browse({}, {})
check("browse lists what it can do, then the parent, folders and files", offered[1], {
  "[Enter URL…]",
  "[Show hidden files]",
  "../",
  "assets/",
  "note.md",
  "pic.png",
})

browse({ insert_dirs = true }, {})
check("browse offers the folder it is in as a target of its own", offered[1][2], "[Insert this folder]")

browse({ filter = function(name)
  return name:match("%.png$") ~= nil
end }, {})
check("browse filters files, never folders", offered[1], {
  "[Enter URL…]",
  "[Show hidden files]",
  "../",
  "assets/",
  "pic.png",
})

-- Sorting, in a tree of its own so the listings checked above stay short.

local mixed = vim.fs.normalize(vim.fn.tempname())
vim.fn.mkdir(mixed .. "/Zed", "p")
vim.fn.mkdir(mixed .. "/apex", "p")
for _, name in ipairs({ "Beta.md", "alpha.md", "Alpha.md", "zulu.md" }) do
  vim.fn.writefile({ "" }, mixed .. "/" .. name)
end

offered, script, answers = {}, {}, {}
file_browser.browse({ dir = mixed, typed_prompt = "Enter URL" }, function() end)
check("browse sorts folders and files together, without regard to case", offered[1], {
  "[Enter URL…]",
  "[Show hidden files]",
  "../",
  "Alpha.md",
  "alpha.md",
  "apex/",
  "Beta.md",
  "Zed/",
  "zulu.md",
})

check("browse answers with an absolute path", browse({}, { "pic.png" }), { path = root .. "/pic.png" })
check(
  "browse walks into a folder before answering",
  browse({}, { "assets/", "cat.png" }),
  { path = root .. "/assets/cat.png" }
)
check(
  "browse answers with the folder it walked into",
  browse({ insert_dirs = true }, { "assets/", "[Insert this folder]" }),
  { path = root .. "/assets" }
)
check("browse answers with typed text", browse({}, { "[Enter URL…]" }, { "www.vg.no" }), { text = "www.vg.no" })
check("browse abandoned answers with nothing", browse({}, {}), nil)
check("browse abandoned at a typed prompt answers with nothing", browse({}, { "[Enter URL…]" }, { "" }), nil)

browse({}, { "[Show hidden files]" })
check("browse hides dotfiles until asked", vim.tbl_contains(offered[1], ".secret.md"), false)
check("browse shows dotfiles once toggled", vim.tbl_contains(offered[2], ".secret.md"), true)
check("browse shows hidden folders too", vim.tbl_contains(offered[2], ".hidden/"), true)
check("browse offers to hide them again", offered[2][2], "[Hide hidden files]")

browse({}, { "[Hide hidden files]" })
check("browse hides them again", vim.tbl_contains(offered[2], ".secret.md"), false)

local document = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_name(document, root .. "/doc.md")
vim.api.nvim_set_current_buf(document)

--- The buffer contents after a generator call, for a document in `root`.
local function inserted(run, choices, typed)
  local bufnr = document
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "word" })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })

  offered, script, answers, prompts = {}, vim.deepcopy(choices), vim.deepcopy(typed), {}
  run()

  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

local generator = require("md-drafting").generator

check("add_link writes what the browser answered, relative to the document", inserted(function()
  generator.add_link({ provider = "File or URL" })
end, { "note.md" }, { "Notes" }), { "word [Notes](note.md)" })

check("add_link names the target it asks the text for", prompts, { "Enter link text (note.md): " })

check("add_link writes a folder as its target", inserted(function()
  generator.add_link({ provider = "File or URL" })
end, { "assets/", "[Insert this folder]" }, { "Assets" }), { "word [Assets](assets)" })

check("add_link writes typed text as it was given", inserted(function()
  generator.add_link({ provider = "File or URL" })
end, { "[Enter URL…]" }, { "www.vg.no", "VG" }), { "word [VG](www.vg.no)" })

check("add_link with no text writes nothing", inserted(function()
  generator.add_link({ provider = "File or URL" })
end, { "note.md" }, { "" }), { "word" })

check("add_image lists only images", inserted(function()
  generator.add_image({ provider = "File or URL" })
end, { "assets/", "cat.png" }, { "A cat" }), { "![A cat](assets/cat.png)", "word" })

check("add_image lists no file that is not an image", vim.tbl_contains(offered[1], "note.md"), false)

check("add_image asks for the alt text after the source, naming it", prompts, {
  "Enter image alt text (assets/cat.png): ",
})

check("add_image writes an image with no alt text", inserted(function()
  generator.add_image({ provider = "File or URL" })
end, { "pic.png" }, { "" }), { "![](pic.png)", "word" })

check("add_image opens where the document is, wherever the last one ended", inserted(function()
  generator.add_image({ provider = "File or URL" })
end, { "pic.png" }, { "A cat" }), { "![A cat](pic.png)", "word" })

check("add_reference_style_link writes its definition from the same answer", inserted(function()
  generator.add_reference_style_link({ provider = "File or URL" })
end, { "note.md" }, { "Notes", "notes" }), { "word [Notes][notes]", "", "[notes]: note.md" })

check("a provider named for no kind writes nothing", inserted(function()
  generator.add_image({ provider = "Nope" })
end, {}, {}), { "word" })

if failures > 0 then
  io.stderr:write(("\n%d of %d checks failed\n"):format(failures, checks))
  os.exit(1)
end

print(("%d checks passed"):format(checks))
