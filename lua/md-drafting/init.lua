local M = {}

local config = require("md-drafting.config")

function M.setup(opts)
  config.options = vim.tbl_deep_extend("force", config.options, opts or {})

  -- Validate config
  if config.options.presentation.width <= 0 then
    vim.notify("md-drafting: presentation.width must be > 0, default to 80", vim.log.levels.ERROR)
    config.options.presentation.width = 80
  end
end

M.presentation = require("md-drafting.modules.presentation")
M.format = require("md-drafting.modules.format")
M.task = require("md-drafting.modules.task")
M.generator = require("md-drafting.modules.generator")
M.actions = require("md-drafting.actions")

-- Action menu
for _, format in ipairs({
  { label = "Bold", pattern = "**" },
  { label = "Italic", pattern = "*" },
  { label = "Strikethrough", pattern = "~~" },
  { label = "Inline code", pattern = "`" },
}) do
  M.actions.register({
    label = format.label,
    prepare = function(opts)
      return M.format.prepare(format.pattern, opts)
    end,
  })
end

M.actions.register({
  label = "Toggle task",
  run = M.task.toggle,
})

M.actions.register({
  label = "Generate TOC",
  run = M.generator.generate_toc,
})

M.actions.register({
  label = "Add callout",
  prepare = function(opts)
    return M.generator.prepare_callout(opts)
  end,
})

M.actions.register({
  label = "Add table",
  run = M.generator.add_table,
})

M.actions.register({
  label = "Add link",
  prepare = function(opts)
    return M.generator.prepare_link(opts)
  end,
})

M.actions.register({
  label = "Add image",
  run = M.generator.add_image,
})

M.actions.register({
  label = "Add footnote",
  run = M.generator.add_footnote,
})

M.actions.register({
  label = "Add reference-style link",
  prepare = function(opts)
    return M.generator.prepare_reference_style_link(opts)
  end,
})

M.actions.register({
  label = "Add code block",
  run = M.generator.add_code_block,
})

M.actions.register({
  label = "Add block quote",
  prepare = function(opts)
    return M.generator.prepare_block_quote(opts)
  end,
})

M.actions.register({
  label = "Start presentation",
  run = M.presentation.start_presentation,
})

return M
