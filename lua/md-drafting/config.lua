local M = {}

M.options = {
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

  presentation = {
    -- Width of the slide. A value of 1 or more is a number of columns, a
    -- value between 0 and 1 is a fraction of the terminal width. Whatever is
    -- left over becomes the margin on either side.
    -- default: 80
    width = 80,

    -- Blank rows between the heading and the slide. Set to 0 to sit the
    -- heading directly on top of the content.
    -- default: 1
    header_gap = 1,

    -- Window options for the slide, merged over these defaults: naming one
    -- replaces it and leaves the rest alone. Line numbers, the sign column
    -- and the colors are not among them -- the first two are off for every
    -- full-screen view, and colors are highlight groups. See the README.
    win_opts = {
      -- Fold long lines at word boundaries rather than mid-word.
      wrap = true,
      linebreak = true,
    },

    -- Navigation, scoped to the presentation buffer.
    keymaps = {
      next = "n",
      previous = "p",
      quit = "q",
    },
  },

  focus_mode = {
    -- Width of the page, read the same way as `presentation.width`.
    -- default: 80
    width = 80,

    -- Blank rows between the heading and the page.
    -- default: 1
    header_gap = 1,

    -- What the heading counts, in the order shown.
    stats = { "words", "lines" },

    -- Window options for the page, merged over these defaults: naming one
    -- replaces it and leaves the rest alone. See the README.
    win_opts = {
      -- Typewriter scrolling: Neovim keeps this many lines above and below the
      -- cursor when it can, and centres it vertically when it cannot.
      scrolloff = 999,

      -- Fold long lines at word boundaries rather than mid-word.
      wrap = true,
      linebreak = true,

      -- Hide the markup the markdown parser marks as concealable, which with
      -- the stock treesitter queries means emphasis markers. 'concealcursor'
      -- is left alone, so markup on the cursor's own line stays visible while
      -- it is being edited.
      conceallevel = 2,

      cursorline = false,
      spell = false,
    },
  },
}

return M
