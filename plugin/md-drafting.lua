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
    vim.api.nvim_buf_create_user_command(bufnr, "MdPresent", drafting.presentation.start_presentation, {})
    vim.api.nvim_buf_create_user_command(bufnr, "MdFocus", drafting.focus.toggle, {})
    vim.api.nvim_buf_create_user_command(bufnr, "MdTypewriter", function()
      drafting.typewriter.toggle()
    end, {})
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
    vim.api.nvim_buf_create_user_command(bufnr, "MdAddLink", drafting.generator.add_link, { range = true })
    vim.api.nvim_buf_create_user_command(bufnr, "MdAddImage", drafting.generator.add_image, {})
    vim.api.nvim_buf_create_user_command(bufnr, "MdAddFootnote", drafting.generator.add_footnote, {})
    vim.api.nvim_buf_create_user_command(bufnr, "MdAddCodeBlock", drafting.generator.add_code_block, {})
    vim.api.nvim_buf_create_user_command(
      bufnr,
      "MdAddReferenceStyleLink",
      drafting.generator.add_reference_style_link,
      { range = true }
    )
    vim.api.nvim_buf_create_user_command(
      bufnr,
      "MdAddBlockQuote",
      drafting.generator.add_block_quote,
      { range = true }
    )
    vim.api.nvim_buf_create_user_command(bufnr, "MdActions", function(opts)
      if #opts.fargs > 0 then
        drafting.actions.open_menu(opts.fargs, opts)
      else
        drafting.actions.open_all(opts)
      end
    end, {
      range = true,
      nargs = "*",
      complete = function()
        return drafting.actions.menu_names()
      end,
    })
  end,
})
