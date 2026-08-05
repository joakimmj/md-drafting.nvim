# md-drafting.nvim

`md-drafting.nvim` is a Neovim plugin providing markdown editing tools —
formatting toggles, task cycling, TOC generation, callouts, and generators.

## ✨ Features

- **Text Formatting:** Toggle **bold**, *italic*, ~~strikethrough~~, and 
  `inline code` on a selection or on the word under the cursor.
- **Actions Menu:** Reach every action from a single picker instead of a
  mapping per command.
- **Task:** Cycle through task list item states (default:
  `<no checkbox> → [ ] → [x]`).
- **TOC Generation:** Generate and regenerate a table of contents from your
  headings.
- **Callouts:** Quote a selection as a Markdown callout block or start an
  empty one (default: GitHub Flavored callouts).
- **Generators:** Quickly create tables, links, images, footnotes, code blocks,
  block quotes, and reference-style links.

## 📦 Installation

Install `md-drafting.nvim` using your favorite plugin manager.

<details>
  <summary>lazy.nvim</summary>

  [lazy.nvim](https://github.com/folke/lazy.nvim)

  ```lua
  {
    "joakimmj/md-drafting.nvim",
    -- Optional: ft = "markdown",
  }
  ```
</details>

<details>
  <summary>packer.nvim</summary>

  [packer.nvim](https://github.com/wbthomason/packer.nvim)

  ```lua
  use "joakimmj/md-drafting.nvim"
  ```
</details>

> [!IMPORTANT]
> This plugin requires `nvim-treesitter` with the `markdown` and
> `markdown_inline` parsers installed.

## ⚙️ Configuration

`md-drafting.nvim` is configured through its `setup()` function. Here is an
example configuration with all the default values:

```lua
require("md-drafting").setup({
  -- Add user commands for all functions in the plugin.
  -- default: false
  add_commands = false,

  -- Markers cycled through by `task.toggle`, in order. A plain list item is
  -- not one of them: cycling past the last marker removes it again.
  task_states = { "[ ]", "[x]" },

  -- Callout types to use for `add_callout`.
  -- These are the GitHub Flavored Markdown callout types.
  callout_types = {
    "NOTE",
    "TIP",
    "IMPORTANT",
    "WARNING",
    "CAUTION",
  },
})
```

### Mappings

This plugin does not come with any default mappings.

You can set up your own keymaps for markdown files by e.g. using
a `FileType` autocommand:

```lua
vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    local md = require("md-drafting")
    local opts = { buffer = true }

    -- Actions menu: everything from one mapping
    vim.keymap.set({ "n", "v" }, "<leader>ma", md.actions.open_menu, vim.tbl_extend("force", opts, { desc = "MD Actions" }))
    vim.keymap.set("i", "<C-c>", md.actions.open_menu, vim.tbl_extend("force", opts, { desc = "MD Actions" }))

    -- Formatting
    vim.keymap.set({ "n", "v" }, "<leader>mfb", md.format.toggle_bold, vim.tbl_extend("force", opts, { desc = "Toggle Bold" }))
    vim.keymap.set({ "n", "v" }, "<leader>mfi", md.format.toggle_italic, vim.tbl_extend("force", opts, { desc = "Toggle Italic" }))
    vim.keymap.set({ "n", "v" }, "<leader>mfs", md.format.toggle_strikethrough, vim.tbl_extend("force", opts, { desc = "Toggle Strikethrough" }))
    vim.keymap.set({ "n", "v" }, "<leader>mfc", md.format.toggle_inline_code, vim.tbl_extend("force", opts, { desc = "Toggle Inline Code" }))

    -- Tasks and contents
    vim.keymap.set("n", "<leader>mt", md.task.toggle, vim.tbl_extend("force", opts, { desc = "Toggle Task" }))
    vim.keymap.set("n", "<leader>mo", md.generator.generate_toc, vim.tbl_extend("force", opts, { desc = "Generate TOC" }))
  end,
})
```

## 🚀 Usage

### Actions menu

`md.actions.open_menu()` offers every action in a `vim.ui.select` picker, so one
mapping reaches all of them. It works on a visual selection, on the word under
the cursor, or on nothing in particular, exactly as the individual functions do.

Features you add yourself can join the same menu rather than growing a second
one:

```lua
require("md-drafting").actions.register({
  label = "Insert today's date",
  run = function()
    vim.api.nvim_put({ os.date("%Y-%m-%d") }, "c", true, true)
  end,
})
```

An action declares either `run(opts)`, performed once chosen, or
`prepare(opts)`, called while the menu is being built and returning the function
to run. `prepare` exists because `vim.ui.select` is asynchronous: visual mode has
already been left by the time a choice comes back, so anything acting on a
selection has to resolve it up front. `md.format.prepare`,
`md.generator.prepare_block_quote` and `md.generator.prepare_callout` are the
same idea for the features that ship with the plugin, and are how those entries
are registered:

```lua
require("md-drafting").actions.register({
  label = "Highlight",
  prepare = function(opts)
    return require("md-drafting").format.prepare("==", opts)
  end,
})
```

### Formatting

The formatting toggles work in three ways, and toggling a second time always
undoes the first:

| Situation | Result |
|---|---|
| Visual selection | The selection is wrapped, or unwrapped if it is already |
| Cursor on a word | That word is wrapped, or unwrapped if it is already |
| Cursor on whitespace | An empty pair is inserted, in insert mode between the markers |

Unwrapping recognises the markers whether they fall inside the selection or just
outside it, so putting the cursor anywhere in `**word**` and toggling bold gives
back `word`. A marker pair is only consumed when it is not part of a longer run,
so toggling italic inside bold text nests as `***word***` rather than mangling
the bold markers.

### Tasks

`md.task.toggle()` cycles the list item under the cursor:

```markdown
- buy milk        →  - [ ] buy milk  →  - [x] buy milk  →  - buy milk
```

Bulleted (`-`, `*`, `+`) and numbered (`1.`, `1)`) list items are both cycled,
nested ones included:

```markdown
1. buy milk       →  1. [ ] buy milk →  1. [x] buy milk →  1. buy milk
```

The markers come from `task_states` and are cycled in order, so a third state
is a matter of configuration:

```lua
require("md-drafting").setup({
  task_states = { "[ ]", "[/]", "[x]" },
})
```

A plain list item is not one of the states: it is where the cycle starts, and
cycling past the last marker returns to it.

### Quotes and callouts

A callout is a block quote with a `> [!TYPE]` line on top of it, so
`md.generator.add_block_quote()` and `md.generator.add_callout()` are the same
operation and behave the same way. Both quote whatever is selected, or the line
under the cursor when nothing is:

```markdown
one       →  > one          →  > [!NOTE]
two          > two             > one
three        > three           > two
                               > three
```

On a blank line there is nothing to quote, so an empty quote is opened and you
land inside it in insert mode. With nothing selected and the cursor already
inside a quote, `add_callout()` gives that quote a header rather than quoting one
of its lines a second time:

```markdown
> already quoted     →  > [!NOTE]
> lines here            > already quoted
                        > lines here
```

### Table of contents

`md.generator.generate_toc()` writes the contents between fixed markers:

```markdown
<!-- TOC -->
- [Title](#title)
  - [Setup](#setup)
<!-- /TOC -->
```

The markers are inserted at the cursor the first time and rewritten in place
afterwards, so regenerating is safe to repeat and picks up headings added or
removed since. Anchors follow GitHub's slugs: lowercased, spaces turned into
hyphens, punctuation dropped, underscores kept.

### Commands

With `add_commands = true`, each function also gets a buffer-local user command
in markdown buffers:

| Command | Description |
|---|---|
| `:MdActions` | Open the actions menu |
| `:MdToggleBold` | Toggle bold |
| `:MdToggleItalic` | Toggle italic |
| `:MdToggleStrikethrough` | Toggle strikethrough |
| `:MdToggleInlineCode` | Toggle inline code |
| `:MdToggleTask` | Cycle the task list item state |
| `:MdGenerateToc` | Generate or regenerate the table of contents |
| `:MdAddCallout` | Quote the current line or selection as a callout |
| `:MdAddTable` | Insert a table skeleton |
| `:MdAddLink` | Insert a link |
| `:MdAddReferenceStyleLink` | Insert a reference-style link |
| `:MdAddImage` | Insert an image |
| `:MdAddFootnote` | Insert a footnote and its definition |
| `:MdAddCodeBlock` | Insert a fenced code block |
| `:MdAddBlockQuote` | Quote the current line or selection |

## API

| Function | Description |
|---|---|
| `md.actions.open_menu(opts?)` | Open the actions picker |
| `md.actions.register(action)` | Add an entry to the actions menu |
| `md.format.toggle_bold(opts?)` | Toggle bold |
| `md.format.toggle_italic(opts?)` | Toggle italic |
| `md.format.toggle_strikethrough(opts?)` | Toggle strikethrough |
| `md.format.toggle_inline_code(opts?)` | Toggle inline code |
| `md.format.prepare(pattern, opts?)` | Resolve the target now, returning a function that applies `pattern` later |
| `md.task.toggle()` | Cycle the task list item state |
| `md.generator.generate_toc()` | Generate or regenerate the table of contents |
| `md.generator.add_callout(opts?)` | Quote the current line or selection as a callout |
| `md.generator.prepare_callout(opts?)` | Resolve the target now, returning a function that quotes it as a callout later |
| `md.generator.add_table()` | Insert a table skeleton |
| `md.generator.add_link(opts?)` | Insert a link |
| `md.generator.prepare_link(opts?)` | Resolve the target now, returning a function that inserts the link later |
| `md.generator.add_reference_style_link(opts?)` | Insert a reference-style link |
| `md.generator.prepare_reference_style_link(opts?)` | Resolve the target now, returning a function that inserts the reference-style link later |
| `md.generator.add_image()` | Insert an image |
| `md.generator.add_footnote()` | Insert a footnote and its definition |
| `md.generator.add_code_block()` | Insert a fenced code block |
| `md.generator.add_block_quote(opts?)` | Quote the current line or selection |
| `md.generator.prepare_block_quote(opts?)` | Resolve the target now, returning a function that quotes it later |

Functions taking `opts?` accept the table Neovim passes to a user command, and
use its `range` to tell whether a selection was given. Called from a mapping
with no arguments they work it out from the current mode instead, so binding
them directly is fine.
