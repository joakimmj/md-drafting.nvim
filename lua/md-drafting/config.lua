local M = {}

M.options = {
  -- Add user commands for all functions in the plugin.
  -- default: false
  add_commands = false,

  -- Checkbox markers, grouped by meaning. `task.toggle` cycles them in the
  -- order given, not_done before done; past the last one a list item goes back
  -- to plain, which is not one of the states.
  task_states = {
    not_done = { "[ ]" },
    done = { "[x]" },
  },

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

    -- Turn typewriter scrolling on when focus mode opens, and off again when
    -- it closes. Configured under `typewriter` below.
    -- default: true
    typewriter = true,

    -- Window options for the page, merged over these defaults: naming one
    -- replaces it and leaves the rest alone. See the README.
    --
    -- 'scrolloff' and 'smoothscroll' are not among them: typewriter scrolling
    -- takes both over while it is on, and puts them back afterwards.
    win_opts = {
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

  -- Typewriter scrolling, which can be toggled in any buffer with
  -- `typewriter.toggle()` and is not tied to focus mode.
  typewriter = {
    -- Where the line being written sits, as a fraction of the window height.
    -- 0.4 puts it a little above the middle, which some people prefer.
    -- default: 0.5
    position = 0.5,
  },
}

return M
