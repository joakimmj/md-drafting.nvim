-- Default options, and the table `setup()` merges the user's over. See
-- `:help md-drafting-config` for what each one does in full.
local M = {}

M.options = {
  -- Add a user command for every function, in markdown buffers.
  add_commands = false,

  -- Checkbox markers, grouped by meaning. `task.toggle` cycles them in the
  -- order given, not_done before done; past the last one a list item goes back
  -- to plain, which is not one of the states.
  task_states = {
    not_done = { "[ ]" },
    done = { "[x]" },
  },

  -- Callout types offered by `add_callout`, GitHub Flavored Markdown's own.
  callout_types = {
    "NOTE",
    "TIP",
    "IMPORTANT",
    "WARNING",
    "CAUTION",
  },

  presentation = {
    -- Slide width: 1 or more is a column count, between 0 and 1 a fraction of
    -- the terminal. The rest becomes the margin on either side.
    width = 80,

    -- Blank rows between the heading and the slide; 0 sits them together.
    header_gap = 1,

    -- Window-local options for the slide, merged over these by key.
    win_opts = {
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
    -- Page width, read the same way as `presentation.width`.
    width = 80,

    -- Blank rows between the heading and the page.
    header_gap = 1,

    -- What the heading counts, in the order shown: "words", "lines".
    stats = { "words", "lines" },

    -- Turn typewriter scrolling on with focus mode, and off again after.
    typewriter = true,

    -- Window-local options for the page, merged over these by key.
    -- 'scrolloff' and 'smoothscroll' belong to typewriter scrolling instead.
    win_opts = {
      wrap = true,
      linebreak = true,

      -- Conceal what the markdown parser marks concealable. 'concealcursor' is
      -- left alone, so markup on the cursor's line stays visible.
      conceallevel = 2,

      cursorline = false,
      spell = false,
    },
  },

  -- Typewriter scrolling, which works in any buffer, focus mode or not.
  typewriter = {
    -- Screen row the line being written is held at, as a fraction of the
    -- window height. 0.4 sits a little above the middle.
    position = 0.5,
  },
}

return M
