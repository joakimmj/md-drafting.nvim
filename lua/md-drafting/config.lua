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
}

return M
