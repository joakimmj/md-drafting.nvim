# 🧩 For plugin authors

The relevant functions for handling markdown files is to be find on the API namespace.

```lua
local api = require("md-drafting").api
```

| Name | What it is |
|---|---|
| `api.syntax` | Every markdown construct the plugin knows, as pure functions over strings — `format_link`, `parse_links`, `parse_list_item`, `parse_checkbox`, `parse_heading`, `format_anchor`, `parse_frontmatter`, and the rest |
| `api.section` | Read and replace a named section between fixed markers — the mechanism the TOC is built on. Two functions, `get` and `set`. See below |
| `api.register_link_provider` | Add a source of link targets, so a link can point at something other than a typed URL |

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

## Link providers

Where `add_link`, `add_reference_style_link` and `add_image` get their target.
This plugin asks; it does not itself know what a link or an image can point at:

```lua
require("md-drafting").api.register_link_provider({
  label = "Engram",
  kinds = { "link" },   -- which callers it is offered to; default: all of them
  resolve = function(ctx, done)
    -- ctx.kind is "link" or "image", ctx.text the label a selection supplied.
    -- Answer done{ text, path } -- text being the link text, or an image's alt
    -- text -- or done(nil) to abort. A callback, not a return value, so a
    -- provider can open a picker of its own.
    done({ text = "My note", path = "my-note.md" })
  end,
})
```

While only one provider is registered for a kind there is no picker — one source
is not a choice. With nothing else registered that is every caller, so inserting
a link does not begin with a menu.

`link_providers.order` names the providers that lead, by label, and the rest
follow in registration order. A caller can also name the one it wants and skip
the question entirely — what a mapping bound at a single source does:

```lua
vim.keymap.set("n", "<leader>mi", function()
  require("md-drafting").generator.add_image({ provider = "File or URL" })
end)
```

`provider` takes a label or a provider itself. A name no provider registered for
that kind answers to is an error, not a reason to ask after all.

One ships with the plugin, `File or URL`: it walks the files around the
document, a directory at a time, and writes the path relative to it, so the link
keeps working wherever the folder is opened from. Each list holds, in order —
folders and files in one listing, sorted without regard to case:

| Entry | Target |
|---|---|
| `[Enter URL…]` | Type it instead — a URL, or a path to something not there yet, written as given |
| `[Insert this folder]` | Link the directory you are in (links only) |
| `[Show hidden files]` | List dotfiles here and from then on |
| `../` | The parent directory |
| `assets/` | Walk into it |
| `cat.png` | The file, written relative to the document |

Every list opens in the document's own directory — the same place every time,
and nothing to configure. `add_image` lists only
`file_or_url.image_extensions`; anything else is still reachable by typing the
path. Nothing is created on disk.

Every caller runs the same way round: the target first, then the text written
about it, prompted as `Enter link text (note.md): ` or `Enter image alt text
(assets/cat.png): `. A link with no text is nothing to click, so an empty answer
abandons it; an image with no alt text is a picture missing its description,
which is the document's business rather than the plugin's, so there an empty
answer is kept. The alt text has no default, deliberately — one derived from the
filename describes the file rather than the picture.

`add_reference_style_link` asks for the reference name after the provider has
answered, the link text being its default. A name the buffer already defines
keeps the definition it has, and the path the provider answered with is dropped.

See `:help md-drafting-api-dependents` and `:help md-drafting-link-providers`.
