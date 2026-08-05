local M = {}

local config = require("md-drafting.config")

function M.setup(opts)
  config.options = vim.tbl_deep_extend("force", config.options, opts or {})
end

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

return M
