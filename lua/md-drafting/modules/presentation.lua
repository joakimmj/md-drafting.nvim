-- Presentation mode: the document split into slides on thematic breaks and
-- rendered one at a time into a scratch buffer.
local M = {}

local config = require("md-drafting.config")
local focused_view = require("md-drafting.lib.focused_view")
local syntax = require("md-drafting.syntax")

local state = {
  view = nil,
  bufnr = nil,
  slides = {},
  current_slide = 1,
  header_left = "",
  header_center = "",
}

-- Presentation mode's highlight groups.
focused_view.define_highlight("MdDraftingPresentationHeader", { link = "MdDraftingHeader" })
focused_view.define_highlight("MdDraftingPresentationNormal", { link = "MdDraftingNormal" })
focused_view.define_highlight("MdDraftingPresentationBackdrop", { link = "MdDraftingBackdrop" })

--- Render the current slide and re-draw the heading.
local function show_slide()
  if not state.view or state.view.closed then
    return
  end

  vim.bo[state.bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(state.bufnr, 0, -1, false, vim.split(state.slides[state.current_slide], "\n"))
  vim.bo[state.bufnr].modifiable = false

  state.view.refresh_header()
end

--- Move by a number of slides, stopping at either end of the deck.
---@param delta integer Slides to move, negative to go back
local function navigate(delta)
  local new_slide = state.current_slide + delta
  if new_slide >= 1 and new_slide <= #state.slides then
    state.current_slide = new_slide
    show_slide()
  end
end

--- Split the current buffer into slides and open the first one.
function M.start_presentation()
  local bufnr = vim.api.nvim_get_current_buf()

  state.slides = {}
  state.header_left = ""
  state.header_center = ""
  state.current_slide = 1

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  local fields, front_matter_end_line = syntax.parse_frontmatter(lines)
  front_matter_end_line = front_matter_end_line or 0

  for _, key in ipairs({ "header_left", "header_center" }) do
    local value = fields and fields[key]
    state[key] = type(value) == "string" and value or ""
  end

  -- Split slides on thematic breaks
  local current_slide_content = {}
  for i = front_matter_end_line + 1, #lines do
    local line = lines[i]
    if syntax.parse_thematic_break(line) then
      if #current_slide_content > 0 then
        table.insert(state.slides, table.concat(current_slide_content, "\n"))
        current_slide_content = {}
      end
    else
      table.insert(current_slide_content, line)
    end
  end

  if #current_slide_content > 0 then
    table.insert(state.slides, table.concat(current_slide_content, "\n"))
  end

  -- trim whitespace from slides
  for i, slide in ipairs(state.slides) do
    state.slides[i] = slide:gsub("^%s*(.-)%s*$", "%1")
  end

  if #state.slides == 0 then
    vim.notify("md-drafting: no slides found, separate them with '---'", vim.log.levels.ERROR)
    return
  end

  -- Slides are rendered into a scratch buffer rather than the document, so the
  -- file being presented is never touched.
  state.bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[state.bufnr].filetype = "markdown"
  vim.bo[state.bufnr].modifiable = false
  vim.bo[state.bufnr].bufhidden = "wipe"
  vim.bo[state.bufnr].swapfile = false

  state.view = focused_view.open({
    buf = state.bufnr,
    width = config.options.presentation.width,
    header = function()
      return focused_view.header_line({
        left = state.header_left,
        center = state.header_center,
        right = string.format("%d/%d", state.current_slide, #state.slides),
      })
    end,
    -- Slide content only changes when navigating, which re-renders the header
    -- itself, so there is nothing to watch for.
    header_events = {},
    header_hl = "MdDraftingPresentationHeader",
    header_gap = config.options.presentation.header_gap,
    normal_hl = "MdDraftingPresentationNormal",
    backdrop = "MdDraftingPresentationBackdrop",
    win_opts = config.options.presentation.win_opts,
  })

  show_slide()

  local keymaps = config.options.presentation.keymaps
  vim.keymap.set("n", keymaps.next, function()
    navigate(1)
  end, { buffer = state.bufnr, silent = true })
  vim.keymap.set("n", keymaps.previous, function()
    navigate(-1)
  end, { buffer = state.bufnr, silent = true })
  vim.keymap.set("n", keymaps.quit, function()
    state.view.close()
  end, { buffer = state.bufnr, silent = true })
end

return M
