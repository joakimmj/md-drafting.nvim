-- Focus mode: the document opened in place, centered on screen, with a heading
-- carrying the file name and a live count.
local M = {}

local config = require("md-drafting.config")
local focused_view = require("md-drafting.lib.focused_view")
local typewriter = require("md-drafting.modules.typewriter")

local state = {
  view = nil,
  origin_win = nil,
  -- Whether focus mode is the one that switched typewriter scrolling on, and
  -- so the one that should switch it off again.
  owns_typewriter = false,
}

-- Focus mode's highlight groups.
focused_view.define_highlight("MdDraftingFocusHeader", { link = "MdDraftingHeader" })
focused_view.define_highlight("MdDraftingFocusNormal", { link = "MdDraftingNormal" })
focused_view.define_highlight("MdDraftingFocusBackdrop", { link = "MdDraftingBackdrop" })

-- What `focus_mode.stats` can name, each counting the whole buffer.
---@type table<string, fun(bufnr: integer): string>
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

--- The counts named by `focus_mode.stats`, in the order given.
---@param bufnr integer Buffer id
---@return string stats Counts, separated by a middot
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

--- The buffer's file name, without its directory.
---@param bufnr integer Buffer id
---@return string name File name, or "[No Name]"
local function filename(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    return "[No Name]"
  end
  return vim.fn.fnamemodify(name, ":t")
end

--- Whether focus mode is showing.
---@return boolean open
local function is_open()
  return state.view ~= nil and not state.view.closed
end

--- Hand the view's state back on the way out: typewriter scrolling if focus
--- mode is what turned it on, and the cursor to the window it came from. That
--- window keeps a position of its own, so without this, writing in the float
--- would end with the cursor back wherever the session happened to start.
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

--- Open focus mode, or close it when it is already open.
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
