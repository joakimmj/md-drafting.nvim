-- Toggling emphasis on a selection, on the word under the cursor, or on nothing
-- in particular.
local M = {}

local syntax = require("md-drafting.syntax")
local util = require("md-drafting.lib.util")

--- Span of the word under the cursor.
---@param line string Line to read
---@param col integer 0-indexed column the cursor is at
---@return integer? start_col 0-indexed start, or nil when there is no word
---@return integer? end_col 0-indexed end, exclusive
local function word_at(line, col)
  local class = "[%w_]"

  local function char_at(i)
    return line:sub(i + 1, i + 1)
  end

  local function is_word(i)
    return char_at(i):match(class) ~= nil
  end

  local function is_blank(i)
    local char = char_at(i)
    return char == "" or char:match("%s") ~= nil
  end

  if is_blank(col) then
    return nil
  end

  local anchor
  if is_word(col) then
    anchor = col
  else
    for i = col, #line - 1 do
      if is_blank(i) then
        break
      end
      if is_word(i) then
        anchor = i
        break
      end
    end

    for i = col, 0, -1 do
      if anchor or is_blank(i) then
        break
      end
      if is_word(i) then
        anchor = i
      end
    end
  end

  if not anchor then
    return nil
  end

  local start_col = anchor
  while start_col > 0 and is_word(start_col - 1) do
    start_col = start_col - 1
  end

  local end_col = anchor + 1
  while end_col < #line and is_word(end_col) do
    end_col = end_col + 1
  end

  return start_col, end_col
end

--- Snapshot what to act on. The actions menu resolves this before opening its
--- picker, since vim.ui.select is asynchronous and visual mode is gone by the
--- time the choice comes back.
---@param bufnr integer Buffer id
---@param opts? table Options a user command was called with
---@return table target Region to act on, or the cursor position when there is none
local function capture_target(bufnr, opts)
  local range = util.selection(bufnr, opts)
  if range then
    return { range = range }
  end

  local win = vim.api.nvim_get_current_win()
  local lnum, col = unpack(vim.api.nvim_win_get_cursor(win))
  local insert = util.in_insert_mode()

  -- No selection, but sitting on a word: treat the word as the region, so a
  -- bare toggle formats it and toggling again strips the markers back off.
  local start_col, end_col = word_at(util.line(bufnr, lnum - 1), col)
  if start_col then
    return { range = { lnum - 1, start_col, lnum - 1, end_col }, win = win, lnum = lnum, insert = insert }
  end

  return { win = win, lnum = lnum, col = col, insert = insert }
end

--- Insert an empty marker pair and leave the cursor between the two, in insert
--- mode.
---@param bufnr integer Buffer id
---@param marker EmphasisMarker Marker to insert
---@param target table Target from capture_target
local function insert_empty_wrapper(bufnr, marker, target)
  local line = util.line(bufnr, target.lnum - 1)
  local col = target.col

  if not target.insert and (#line == 0 or col >= #line - 1) then
    col = #line
  end

  vim.api.nvim_buf_set_text(bufnr, target.lnum - 1, col, target.lnum - 1, col, { syntax.format_emphasis("", marker) })
  util.start_insert(bufnr, target.win, target.lnum, col + #marker)
end

--- Whether the selection is immediately surrounded by the marker pair, e.g.
--- `world` selected inside `**world**`. A pair that is part of a longer run is
--- not one, so toggling italic inside bold nests instead of mangling it.
---@param bufnr integer Buffer id
---@param marker EmphasisMarker Marker to look for
---@param start_row integer 0-indexed start row
---@param start_col integer 0-indexed start column
---@param end_row integer 0-indexed end row
---@param end_col integer 0-indexed end column, exclusive
---@return boolean wrapped
local function is_wrapped_outside(bufnr, marker, start_row, start_col, end_row, end_col)
  if start_col < #marker then
    return false
  end

  local start_line = util.line(bufnr, start_row)
  local end_line = util.line(bufnr, end_row)

  local before = start_line:sub(start_col - #marker + 1, start_col)
  local after = end_line:sub(end_col + 1, end_col + #marker)
  if before ~= marker or after ~= marker then
    return false
  end

  local before_outer = start_line:sub(start_col - 2 * #marker + 1, start_col - #marker)
  local after_outer = end_line:sub(end_col + #marker + 1, end_col + 2 * #marker)
  return not (before_outer == marker and after_outer == marker)
end

--- Carry on typing where the formatted text now ends, so that reaching for a
--- format mid-sentence does not drop out of insert mode.
---@param bufnr integer Buffer id
---@param target table Target from capture_target
---@param lnum integer 1-indexed row to resume on
---@param col integer 0-indexed column to resume at
local function resume_insert(bufnr, target, lnum, col)
  if target.insert then
    util.start_insert(bufnr, target.win, lnum, col)
  end
end

--- Wrap the target in the marker, or unwrap it when it already is.
---@param bufnr integer Buffer id
---@param marker EmphasisMarker Marker to toggle
---@param target table Target from capture_target
local function apply_format(bufnr, marker, target)
  if not target.range then
    insert_empty_wrapper(bufnr, marker, target)
    return
  end

  local start_row, start_col, end_row, end_col = unpack(target.range)
  local selection = table.concat(vim.api.nvim_buf_get_text(bufnr, start_row, start_col, end_row, end_col, {}), "\n")

  -- Markers inside the selection, e.g. `**world**` selected whole.
  if #selection >= 2 * #marker and selection:sub(1, #marker) == marker and selection:sub(-#marker) == marker then
    local stripped = selection:sub(#marker + 1, -#marker - 1)
    vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, vim.split(stripped, "\n"))
    resume_insert(bufnr, target, end_row + 1, start_col + #stripped)
    return
  end

  -- Markers just outside the selection, e.g. `world` selected inside
  -- `**world**`. Drop them and keep the selected text as-is.
  if is_wrapped_outside(bufnr, marker, start_row, start_col, end_row, end_col) then
    vim.api.nvim_buf_set_text(
      bufnr,
      start_row,
      start_col - #marker,
      end_row,
      end_col + #marker,
      vim.split(selection, "\n")
    )
    resume_insert(bufnr, target, end_row + 1, start_col - #marker + #selection)
    return
  end

  local wrapped = syntax.format_emphasis(selection, marker)
  vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, vim.split(wrapped, "\n"))
  resume_insert(bufnr, target, end_row + 1, start_col + #marker * 2 + #selection)
end

--- Resolve what to act on now and return a function that performs the toggle
--- later. Anything that picks a format asynchronously has to capture the target
--- up front, since the selection is gone once the picker takes over.
---@param marker EmphasisMarker Marker to toggle, e.g. syntax.EMPHASIS.bold
---@param opts? table Options a user command was called with
---@return fun() toggle Applies the marker to the captured target
function M.prepare(marker, opts)
  local bufnr = vim.api.nvim_get_current_buf()
  local target = capture_target(bufnr, opts)
  return function()
    apply_format(bufnr, marker, target)
  end
end

--- Toggle a marker on the selection, the word under the cursor, or nothing.
---@param marker EmphasisMarker Marker to toggle
---@param opts? table Options a user command was called with
local function toggle_format(marker, opts)
  M.prepare(marker, opts)()
end

--- Toggle bold.
---@param opts? table Options a user command was called with
function M.toggle_bold(opts)
  toggle_format(syntax.EMPHASIS.bold, opts)
end

--- Toggle italic.
---@param opts? table Options a user command was called with
function M.toggle_italic(opts)
  toggle_format(syntax.EMPHASIS.italic, opts)
end

--- Toggle strikethrough.
---@param opts? table Options a user command was called with
function M.toggle_strikethrough(opts)
  toggle_format(syntax.EMPHASIS.strikethrough, opts)
end

--- Toggle inline code.
---@param opts? table Options a user command was called with
function M.toggle_inline_code(opts)
  toggle_format(syntax.EMPHASIS.code, opts)
end

return M
