local M = {}

local config = require("md-drafting.config")

function M.setup(opts)
  config.options = vim.tbl_deep_extend("force", config.options, opts or {})
end

M.format = require("md-drafting.modules.format")
M.task = require("md-drafting.modules.task")
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

return M
