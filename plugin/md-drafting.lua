local config = require("md-drafting.config")

vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  group = vim.api.nvim_create_augroup("md-drafting-commands", { clear = true }),
  callback = function(event)
    if not config.options.add_commands then
      return
    end

    -- Commands are registered here as features land.
  end,
})
