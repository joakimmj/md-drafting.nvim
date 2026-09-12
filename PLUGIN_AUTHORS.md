# 🧩 For plugin authors

The relevant functions for handling markdown files is to be find on the API namespace.

```lua
local api = require("md-drafting").api
```

| Name | What it is |
|---|---|
| `api.syntax` | Every markdown construct the plugin knows, as pure functions over strings — `format_link`, `parse_links`, `parse_list_item`, `parse_checkbox`, `parse_heading`, `format_anchor`, `parse_frontmatter`, and the rest |
| `api.section` | Read and replace a named section between fixed markers — the mechanism the TOC is built on. Two functions, `get` and `set`. See below |


## Fenced sections

A section is a body of lines between a fixed marker pair — `<!-- NAME -->` and
`<!-- /NAME -->`, a constant rather than a setting, so a section this plugin
wrote and one you wrote are the same thing. It is how the table of contents is
generated, and it is yours for anything with the same shape.

```lua
api.section.get(lines, name)              --> string[], or nil when there is no section
api.section.set(lines, name, body, opts?) --> the rewritten lines
```

Both work over a plain list of lines, so a file you never opened in a buffer is
rewritten the same way as one you did. `set` replaces the body wholesale and
writes the section itself when the lines have none yet — at `opts.at` (a
1-indexed row) or at the end. It is safe to re-run: the result depends only on
`body`, never on what was there before.

The pair round-trips — `get(set(lines, name, body), name)` is `body` — which is
what makes every other edit a composition rather than a function of its own:

```lua
local body = api.section.get(lines, "LOG") or {}
table.insert(body, "- " .. entry)
lines = api.section.set(lines, "LOG", body)
```

Appending, prepending, dropping a line, sorting, de-duplicating: all of them are
those two with your own edit in between, and none of them needs this plugin to
have anticipated it. An empty section is an empty list, which is not the same
answer as `nil` — there being no section at all.

Content outside the markers is never touched, so a hand-written introduction
above a generated block survives every regeneration.

Neither function touches a buffer — they are pure, and a file you are rewriting
on disk never needed one. For a buffer, read with `nvim_buf_get_lines` and write
the result back yourself, but trim the common prefix and suffix off first and
write only what is left:

```lua
local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
local updated = api.section.set(lines, "LOG", body)
-- write only the rows that differ; see below for why
```

`nvim_buf_set_lines(bufnr, 0, -1, false, updated)` is the obvious thing and the
wrong one: it drags every extmark in the buffer to the end of the replaced
range, so the reader's signs, diagnostics and git hunks all jump to the bottom
of the file — and it does that even when the lines you write are identical to
the ones already there.
