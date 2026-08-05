local M = {}

local config = require("md-drafting.config")

function M.setup(opts)
  config.options = vim.tbl_deep_extend("force", config.options, opts or {})
end

M.format = require("md-drafting.modules.format")

return M
