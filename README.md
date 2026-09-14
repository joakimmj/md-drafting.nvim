# md-drafting.nvim

Markdown editing tools for Neovim: formatting toggles, task cycling, TOC
generation, callouts, generators, jump navigation, and built-in presentation
and focus modes.

Full reference: `:help md-drafting`.

## ✨ Features

- **Text Formatting:** Toggle **bold**, *italic*, ~~strikethrough~~ and
  `inline code` on a selection or on the word under the cursor.
- **Actions Menus:** Reach every action from a single picker, or bind a
  smaller, named menu — your own or the built-in `formatting`, `insert` and
  `view` ones.
- **Task:** Cycle through task list item states.
- **TOC Generation:** Generate and regenerate a table of contents.
- **Callouts:** Quote a selection as a callout block or start an empty one.
- **Generators:** Tables, links, images, footnotes, code blocks, block quotes
  and reference-style links.
- **Jump Navigation:** Move between links, headings, tasks, code blocks,
  tables, thematic breaks and footnotes.
- **Presentation Mode:** View the file as a slide deck inside Neovim.
- **Focus Mode:** Distraction-free writing — centered page, typewriter
  scrolling, live word count.

## 📦 Installation

<details>
  <summary>vim.pack</summary>

  Built into Neovim 0.12 and later.

  ```lua
  vim.pack.add({
    "https://github.com/joakimmj/md-drafting.nvim",
  })
  ```
</details>

<details>
  <summary>lazy.nvim</summary>

  ```lua
  {
    "joakimmj/md-drafting.nvim",
    -- Optional: ft = "markdown",
  }
  ```
</details>

<details>
  <summary>packer.nvim</summary>

  ```lua
  use "joakimmj/md-drafting.nvim"
  ```
</details>

> [!IMPORTANT]
> Requires Neovim 0.10 or later, and `nvim-treesitter` with the `markdown` and
> `markdown_inline` parsers.

## ⚙️ Configuration

Every value below is the default, so an empty `setup()` call — or none at
all — gives exactly this. See `:help md-drafting-config`.

```lua
require("md-drafting").setup({
  -- Add a user command for every function, in markdown buffers.
  add_commands = false,

  -- Checkbox markers, grouped by meaning. `task.toggle` cycles not_done
  -- before done, then back to a plain list item.
  task_states = {
    not_done = { "[ ]" },
    done = { "[x]" },
  },

  -- Callout types offered by `add_callout`.
  callout_types = { "NOTE", "TIP", "IMPORTANT", "WARNING", "CAUTION" },

  presentation = {
    -- 1 or more is a column count, between 0 and 1 a fraction of the terminal.
    width = 80,
    -- Blank rows between the heading and the slide.
    header_gap = 1,
    -- Window-local options for the slide, merged over these by key.
    win_opts = { wrap = true, linebreak = true },
    -- Navigation, scoped to the presentation buffer.
    keymaps = { next = "n", previous = "p", quit = "q" },
  },

  focus_mode = {
    width = 80,
    header_gap = 1,
    -- What the heading counts, in the order shown: "words", "lines".
    stats = { "words", "lines" },
    -- Turn typewriter scrolling on with focus mode, and off again after.
    typewriter = true,
    win_opts = {
      wrap = true,
      linebreak = true,
      conceallevel = 2,
      cursorline = false,
      spell = false,
    },
  },

  typewriter = {
    -- Screen row the line being written is held at, as a fraction of the
    -- window height.
    position = 0.5,
  },
})
```

Maps merge by key, so one `win_opts` entry leaves the rest alone. Lists replace
wholesale.

### Mappings

No default keymaps, except presentation mode's `n` / `p` / `q`, which are
buffer-local to the view it creates. Set up your own by e.g. using a `FileType`
autocommand to only add them for markdown files:

```lua
vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    local md = require("md-drafting")
    local opts = { buffer = true }
    vim.keymap.set({ "n", "v" }, "<leader>ma", md.actions.open_all, opts)
  end,
})
```

See `:help md-drafting-mappings`.

### Commands

Every function below also has a buffer-local user command in markdown buffers,
listed alongside it — but only with `add_commands = true`.

Functions taking `opts?` accept the table Neovim passes to a user command and
use its `range` to tell whether a selection was given. Called from a mapping
with no arguments they work it out from the current mode instead.

## ✍️ Editing

### Actions menus

`md.actions.open_all()` offers every action in a `vim.ui.select` picker;
`md.actions.open_menu(name)` offers one. Both work on a selection, on the word
under the cursor, or on nothing, exactly as the individual functions do.

| Menu | Actions |
|---|---|
| `formatting` | Bold, Italic, Strikethrough, Inline code, Toggle task |
| `insert` | Generate TOC, Add callout, Add table, Add link, Add image, Add footnote, Add reference-style link, Add code block, Add block quote |
| `view` | Start presentation, Toggle focus mode, Jump to next…, Jump to prev…, Toggle typewriter scrolling |

<details>
<summary>Functions</summary>

| Function | Description |
|---|---|
| `md.actions.open_all(opts?)` | Open a picker with every action |
| `md.actions.open_menu(names, opts?)` | Open a picker with one menu, or several |
| `md.actions.register(menu, action)` | Add an entry to a menu |
| `md.actions.menu_names()` | The registered menu names, sorted |

</details>

<details>
<summary>Commands</summary>

| Command | Description |
|---|---|
| `:MdActions [menu ...]` | Open the actions menu, or the named menus given |

</details>

Register your own into those menus, or into one of your own:

```lua
require("md-drafting").actions.register("insert", {
  label = "Insert today's date",
  run = function()
    vim.api.nvim_put({ os.date("%Y-%m-%d") }, "c", true, true)
  end,
})
```

An action declares `run(opts)`, or `prepare(opts)` when it acts on a selection —
`vim.ui.select` is asynchronous, so the target has to be resolved up front. See
`:help md-drafting-actions`.

### Formatting

Wrap the selection, or the word under the cursor, in a marker — or unwrap it
when it already is. On whitespace, an empty pair is inserted in insert mode.
See `:help md-drafting-format`.

<details>
<summary>Functions</summary>

| Function | Description |
|---|---|
| `md.format.toggle_bold(opts?)` | Toggle bold |
| `md.format.toggle_italic(opts?)` | Toggle italic |
| `md.format.toggle_strikethrough(opts?)` | Toggle strikethrough |
| `md.format.toggle_inline_code(opts?)` | Toggle inline code |
| `md.format.prepare(marker, opts?)` | Resolve the target now, apply `marker` later |

</details>

<details>
<summary>Commands</summary>

| Command | Description |
|---|---|
| `:MdToggleBold` | Toggle bold |
| `:MdToggleItalic` | Toggle italic |
| `:MdToggleStrikethrough` | Toggle strikethrough |
| `:MdToggleInlineCode` | Toggle inline code |

</details>

### Tasks

Cycle the list item under the cursor through the `task_states` markers —
`not_done` in order, then `done`, then back to a plain list item. Bulleted and
numbered items both, nested ones included. See `:help md-drafting-tasks`.

```markdown
- buy milk        →  - [ ] buy milk  →  - [x] buy milk  →  - buy milk
```

<details>
<summary>Functions</summary>

| Function | Description |
|---|---|
| `md.task.toggle()` | Cycle the task list item state |

</details>

<details>
<summary>Commands</summary>

| Command | Description |
|---|---|
| `:MdToggleTask` | Cycle the task list item state |

</details>

### Generators

Insert the constructs that are tedious to type. The `prepare_*` variants
resolve the target now and apply it later, for anything asynchronous —
see `:help md-drafting-actions-prepare`.

<details>
<summary>Functions</summary>

| Function | Description |
|---|---|
| `md.generator.generate_toc()` | Generate or regenerate the table of contents (`:help md-drafting-toc`) |
| `md.generator.add_callout(opts?)` | Quote the current line or selection as a callout (`:help md-drafting-toc`) |
| `md.generator.prepare_callout(opts?)` | As above, resolved now and applied later |
| `md.generator.add_block_quote(opts?)` | Quote the current line or selection |
| `md.generator.prepare_block_quote(opts?)` | As above, resolved now and applied later |
| `md.generator.add_link(opts?)` | Insert a link |
| `md.generator.prepare_link(opts?)` | As above, resolved now and applied later |
| `md.generator.add_reference_style_link(opts?)` | Insert a reference-style link |
| `md.generator.prepare_reference_style_link(opts?)` | As above, resolved now and applied later |
| `md.generator.add_table()` | Insert a table skeleton |
| `md.generator.add_image()` | Insert an image |
| `md.generator.add_footnote()` | Insert a footnote and its definition |
| `md.generator.add_code_block()` | Insert a fenced code block |

</details>

<details>
<summary>Commands</summary>

| Command | Description |
|---|---|
| `:MdGenerateToc` | Generate or regenerate the table of contents |
| `:MdAddCallout` | Quote the current line or selection as a callout |
| `:MdAddBlockQuote` | Quote the current line or selection |
| `:MdAddLink` | Insert a link |
| `:MdAddReferenceStyleLink` | Insert a reference-style link |
| `:MdAddTable` | Insert a table skeleton |
| `:MdAddImage` | Insert an image |
| `:MdAddFootnote` | Insert a footnote and its definition |
| `:MdAddCodeBlock` | Insert a fenced code block |

</details>

### Jump navigation

Move the cursor to the next or previous occurrence of a construct. Both wrap
around the buffer, and do nothing but report when there is no match.
See `:help md-drafting-jump`.

<details>
<summary>Functions</summary>

| Function | Description |
|---|---|
| `md.jump.next(target)` | Move to the next occurrence, wrapping to the first |
| `md.jump.previous(target)` | Move to the previous occurrence, wrapping to the last |
| `md.jump.target_names()` | The target names, in the order the menu offers them |
| `md.jump.TARGETS` | The targets, by name |

</details>

<details>
<summary>Commands</summary>

| Command | Description |
|---|---|
| `:MdJumpNext <target>` | Move to the next occurrence of a construct |
| `:MdJumpPrevious <target>` | Move to the previous occurrence of a construct |

</details>

| Target | Moves between |
|---|---|
| `LINK` | inline links, images skipped |
| `REFERENCE_LINK` | reference-style links and their definitions |
| `HEADING` | `#` through `######`, read from the syntax tree |
| `TASK` | list items carrying a checkbox, whatever its state |
| `NOT_DONE_TASK` | list items whose checkbox is one of `task_states.not_done` |
| `CODE_BLOCK` | fenced code blocks |
| `TABLE` | tables |
| `THEMATIC_BREAK` | `---`, `***`, `___` |
| `FOOTNOTE` | footnote references and their definitions |

The commands take the lowercase name (`:MdJumpNext not_done_task`), which is
what they complete on.

### Typewriter scrolling

The line you are writing keeps a fixed height on screen while the text moves
under it. Works in any buffer, switched on **per buffer**, and focus mode turns
it on with it unless `focus_mode.typewriter = false`. While it is on,
`scrolloff` and `smoothscroll` belong to it.
See `:help md-drafting-typewriter`.

<details>
<summary>Functions</summary>

| Function | Description |
|---|---|
| `md.typewriter.toggle(bufnr?)` | Toggle typewriter scrolling |
| `md.typewriter.enable(bufnr?)` | Turn typewriter scrolling on |
| `md.typewriter.disable(bufnr?)` | Turn typewriter scrolling off |
| `md.typewriter.is_enabled(bufnr?)` | Whether it is on for that buffer |

</details>

<details>
<summary>Commands</summary>

| Command | Description |
|---|---|
| `:MdTypewriter` | Toggle typewriter scrolling |

</details>

## 🚀 Full-screen Views

### Presentation mode

Slides split on thematic breaks; optional frontmatter supplies the header,
which also carries a slide counter. Slides render into a scratch buffer, so the
document is never modified. Navigate with `n` / `p` / `q`.
See `:help md-drafting-presentation`.

```markdown
---
header_left: My Talk
header_center: Introduction
---

# First slide

---

# Second slide
```

<details>
<summary>Functions</summary>

| Function | Description |
|---|---|
| `md.presentation.start_presentation()` | Start presentation mode |

</details>

<details>
<summary>Commands</summary>

| Command | Description |
|---|---|
| `:MdPresent` | Start presentation mode |

</details>

### Focus mode

The document centered on screen, the rest of the editor hidden behind it, file
name and live word count in the heading. This is **your document, opened in
place** — `:w` works normally — and closing carries the cursor back to the
window you started from. `:q` closes it too. See `:help md-drafting-focus`.

<details>
<summary>Functions</summary>

| Function | Description |
|---|---|
| `md.focus.toggle()` | Toggle focus mode |

</details>

<details>
<summary>Commands</summary>

| Command | Description |
|---|---|
| `:MdFocus` | Toggle focus mode |

</details>

### Colors

Highlight groups, not settings, so a colorscheme can theme the plugin. The
shared groups apply to every full-screen view:

| Group | Links to | Used for |
|---|---|---|
| `MdDraftingHeader` | `StatusLine` | The heading strip |
| `MdDraftingNormal` | `Normal` | The page, and the gap under the heading |
| `MdDraftingBackdrop` | `Normal` | The margin on either side |

Each mode links its own groups to those —
`MdDraftingPresentation{Header,Normal,Backdrop}` and
`MdDraftingFocus{Header,Normal,Backdrop}` — so one mode can be retinted without
disturbing the other:

```lua
vim.api.nvim_set_hl(0, "MdDraftingBackdrop", { bg = "#11111b" })
```

All are defined with `default = true`, so your own definitions win.
See `:help md-drafting-colors`.
