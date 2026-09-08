local M = {}

local config = require("md-drafting.config")
local focused_view = require("md-drafting.lib.focused_view")
local typewriter = require("md-drafting.modules.typewriter")

local state = {
  view = nil,
  origin_win = nil,
}

-- Focus mode's highlight groups.
focused_view.define_highlight("MdDraftingFocusHeader", { link = "MdDraftingHeader" })
focused_view.define_highlight("MdDraftingFocusNormal", { link = "MdDraftingNormal" })
focused_view.define_highlight("MdDraftingFocusBackdrop", { link = "MdDraftingBackdrop" })

-- Status available to show in header.
local STATS = {
  words = function(bufnr)
    local counted = vim.api.nvim_buf_call(bufnr, vim.fn.wordcount)
    return counted.words .. (counted.words == 1 and " word" or " words")
  end,

  lines = function(bufnr)
    local counted = vim.api.nvim_buf_line_count(bufnr)
    return counted .. (counted == 1 and " line" or " lines")
  end,
}

local function stats(bufnr)
  local parts = {}

  for _, name in ipairs(config.options.focus_mode.stats) do
    local count = STATS[name]
    if count then
      table.insert(parts, count(bufnr))
    end
  end

  return table.concat(parts, " · ")
end

local function filename(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    return "[No Name]"
  end
  return vim.fn.fnamemodify(name, ":t")
end

local function is_open()
  return state.view ~= nil and not state.view.closed
end

-- The document stays displayed in the window focus mode was started from, and
-- that window keeps a cursor position of its own. Without this, writing in the
-- float would end with the cursor back wherever the session happened to start.
local function on_close()
  -- Only if focus mode turned it on: it can also be switched on by hand, in
  -- which case leaving focus mode is no reason to take it away.
  if state.owns_typewriter then
    typewriter.disable(state.view.buf)
    state.owns_typewriter = false
  end

  local position = state.view and state.view.cursor()
  local origin = state.origin_win

  if not position or not origin or not vim.api.nvim_win_is_valid(origin) then
    return
  end

  -- Only if that window is still showing the same document: it may have been
  -- moved elsewhere while the view was open.
  if vim.api.nvim_win_get_buf(origin) ~= state.view.buf then
    return
  end

  position[1] = math.min(position[1], vim.api.nvim_buf_line_count(state.view.buf))
  pcall(vim.api.nvim_win_set_cursor, origin, position)
end

function M.toggle()
  if is_open() then
    state.view.close()
    return
  end

  -- The real document, not a copy: focus mode is for writing in it.
  local bufnr = vim.api.nvim_get_current_buf()
  state.origin_win = vim.api.nvim_get_current_win()

  state.view = focused_view.open({
    buf = bufnr,
    width = config.options.focus_mode.width,
    header = function()
      return focused_view.header_line({
        left = filename(bufnr),
        right = stats(bufnr),
      })
    end,
    -- The stats count the whole buffer, so only editing can change them —
    -- moving the cursor cannot, and counting again on every motion would be
    -- wasted work on a long document.
    header_events = { "TextChanged", "TextChangedI" },
    header_hl = "MdDraftingFocusHeader",
    header_gap = config.options.focus_mode.header_gap,
    normal_hl = "MdDraftingFocusNormal",
    backdrop = "MdDraftingFocusBackdrop",
    win_opts = config.options.focus_mode.win_opts,
    on_close = on_close,
  })

  if config.options.focus_mode.typewriter and not typewriter.is_enabled(bufnr) then
    typewriter.enable(bufnr)
    state.owns_typewriter = true
  end

  -- Start where the document was left, rather than at the top of the file.
  local position = vim.api.nvim_win_get_cursor(state.origin_win)
  pcall(vim.api.nvim_win_set_cursor, state.view.win, position)
  state.view.refresh_header()
end

return M
