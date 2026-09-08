local M = {}

local config = require("md-drafting.config")
local syntax = require("md-drafting.syntax")

function M.setup(opts)
  config.options = vim.tbl_deep_extend("force", config.options, opts or {})

  -- Validate config
  for _, mode in ipairs({ "presentation", "focus_mode" }) do
    if config.options[mode].width <= 0 then
      vim.notify(("md-drafting: %s.width must be > 0, default to 80"):format(mode), vim.log.levels.ERROR)
      config.options[mode].width = 80
    end
  end

  -- A position outside the window is not a row the cursor can be held on.
  local typewriter = config.options.typewriter
  if typewriter.position <= 0 or typewriter.position > 1 then
    vim.notify("md-drafting: typewriter.position must be > 0 and <= 1, default to 0.5", vim.log.levels.ERROR)
    typewriter.position = 0.5
  end
end

M.presentation = require("md-drafting.modules.presentation")
M.focus = require("md-drafting.modules.focus")
M.typewriter = require("md-drafting.modules.typewriter")
M.format = require("md-drafting.modules.format")
M.task = require("md-drafting.modules.task")
M.generator = require("md-drafting.modules.generator")
M.actions = require("md-drafting.lib.actions")

-- Action menus
for _, format in ipairs({
  { label = "Bold", pattern = syntax.EMPHASIS.bold },
  { label = "Italic", pattern = syntax.EMPHASIS.italic },
  { label = "Strikethrough", pattern = syntax.EMPHASIS.strikethrough },
  { label = "Inline code", pattern = syntax.EMPHASIS.code },
}) do
  M.actions.register("formatting", {
    label = format.label,
    prepare = function(opts)
      return M.format.prepare(format.pattern, opts)
    end,
  })
end

M.actions.register("formatting", {
  label = "Toggle task",
  run = M.task.toggle,
})

M.actions.register("insert", {
  label = "Generate TOC",
  run = M.generator.generate_toc,
})

M.actions.register("insert", {
  label = "Add callout",
  prepare = function(opts)
    return M.generator.prepare_callout(opts)
  end,
})

M.actions.register("insert", {
  label = "Add table",
  run = M.generator.add_table,
})

M.actions.register("insert", {
  label = "Add link",
  prepare = function(opts)
    return M.generator.prepare_link(opts)
  end,
})

M.actions.register("insert", {
  label = "Add image",
  run = M.generator.add_image,
})

M.actions.register("insert", {
  label = "Add footnote",
  run = M.generator.add_footnote,
})

M.actions.register("insert", {
  label = "Add reference-style link",
  prepare = function(opts)
    return M.generator.prepare_reference_style_link(opts)
  end,
})

M.actions.register("insert", {
  label = "Add code block",
  run = M.generator.add_code_block,
})

M.actions.register("insert", {
  label = "Add block quote",
  prepare = function(opts)
    return M.generator.prepare_block_quote(opts)
  end,
})

M.actions.register("view", {
  label = "Start presentation",
  run = M.presentation.start_presentation,
})

M.actions.register("view", {
  label = "Toggle focus mode",
  run = M.focus.toggle,
})

M.actions.register("view", {
  label = "Toggle typewriter scrolling",
  run = function()
    M.typewriter.toggle()
  end,
})

return M
