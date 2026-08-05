local config = require("md-drafting.config")
local drafting = require("md-drafting")

vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  group = vim.api.nvim_create_augroup("md-drafting-commands", { clear = true }),
  callback = function(event)
    if not config.options.add_commands then
      return
    end

    local bufnr = event.buf
    vim.api.nvim_buf_create_user_command(bufnr, "MdToggleBold", drafting.format.toggle_bold, { range = true })
    vim.api.nvim_buf_create_user_command(bufnr, "MdToggleItalic", drafting.format.toggle_italic, { range = true })
    vim.api.nvim_buf_create_user_command(
      bufnr,
      "MdToggleStrikethrough",
      drafting.format.toggle_strikethrough,
      { range = true }
    )
    vim.api.nvim_buf_create_user_command(
      bufnr,
      "MdToggleInlineCode",
      drafting.format.toggle_inline_code,
      { range = true }
    )
    vim.api.nvim_buf_create_user_command(bufnr, "MdToggleTask", drafting.task.toggle, {})
    vim.api.nvim_buf_create_user_command(bufnr, "MdGenerateToc", drafting.generator.generate_toc, {})
    vim.api.nvim_buf_create_user_command(bufnr, "MdAddCallout", drafting.generator.add_callout, { range = true })
    vim.api.nvim_buf_create_user_command(bufnr, "MdAddTable", drafting.generator.add_table, {})
    vim.api.nvim_buf_create_user_command(bufnr, "MdActions", drafting.actions.open_menu, { range = true })
  end,
})
