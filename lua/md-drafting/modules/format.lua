local M = {}

local util = require("md-drafting.util")

-- Span of the word under the cursor, as 0-indexed columns with an exclusive
-- end, or nil when there is no word to act on.
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

-- Snapshot what to act on. The actions menu resolves this before opening its
-- picker, since vim.ui.select is asynchronous and visual mode is gone by the
-- time the choice comes back.
local function capture_target(bufnr, opts)
  local range = util.selection(bufnr, opts)
  if range then
    return { range = range }
  end

  local win = vim.api.nvim_get_current_win()
  local row, col = unpack(vim.api.nvim_win_get_cursor(win))
  local insert = util.in_insert_mode()

  -- No selection, but sitting on a word: treat the word as the region, so a
  -- bare toggle formats it and toggling again strips the markers back off.
  local start_col, end_col = word_at(util.line(bufnr, row - 1), col)
  if start_col then
    return { range = { row - 1, start_col, row - 1, end_col }, win = win, row = row, insert = insert }
  end

  return { win = win, row = row, col = col, insert = insert }
end

-- Insert an empty wrapper pair and leave the cursor between the markers, in
-- insert mode
local function insert_empty_wrapper(bufnr, pattern, target)
  local line = util.line(bufnr, target.row - 1)
  local col = target.col

  if not target.insert and (#line == 0 or col >= #line - 1) then
    col = #line
  end

  vim.api.nvim_buf_set_text(bufnr, target.row - 1, col, target.row - 1, col, { pattern .. pattern })
  util.start_insert(bufnr, target.win, target.row, col + #pattern)
end

-- True when the selection is immediately surrounded by the marker pair, e.g.
-- `world` selected inside `**world**`.
local function is_wrapped_outside(bufnr, pattern, start_row, start_col, end_row, end_col)
  if start_col < #pattern then
    return false
  end

  local start_line = util.line(bufnr, start_row)
  local end_line = util.line(bufnr, end_row)

  local before = start_line:sub(start_col - #pattern + 1, start_col)
  local after = end_line:sub(end_col + 1, end_col + #pattern)
  if before ~= pattern or after ~= pattern then
    return false
  end

  local before_outer = start_line:sub(start_col - 2 * #pattern + 1, start_col - #pattern)
  local after_outer = end_line:sub(end_col + #pattern + 1, end_col + 2 * #pattern)
  return not (before_outer == pattern and after_outer == pattern)
end

-- Carry on typing where the formatted text now ends, so that reaching for a
-- format mid-sentence does not drop out of insert mode.
local function resume_insert(bufnr, target, row, col)
  if target.insert then
    util.start_insert(bufnr, target.win, row, col)
  end
end

local function apply_format(bufnr, pattern, target)
  if not target.range then
    insert_empty_wrapper(bufnr, pattern, target)
    return
  end

  local start_row, start_col, end_row, end_col = unpack(target.range)
  local selection = table.concat(vim.api.nvim_buf_get_text(bufnr, start_row, start_col, end_row, end_col, {}), "\n")

  -- Markers inside the selection, e.g. `**world**` selected whole.
  if #selection >= 2 * #pattern and selection:sub(1, #pattern) == pattern and selection:sub(-#pattern) == pattern then
    local stripped = selection:sub(#pattern + 1, -#pattern - 1)
    vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, vim.split(stripped, "\n"))
    resume_insert(bufnr, target, end_row + 1, start_col + #stripped)
    return
  end

  -- Markers just outside the selection, e.g. `world` selected inside
  -- `**world**`. Drop them and keep the selected text as-is.
  if is_wrapped_outside(bufnr, pattern, start_row, start_col, end_row, end_col) then
    vim.api.nvim_buf_set_text(
      bufnr,
      start_row,
      start_col - #pattern,
      end_row,
      end_col + #pattern,
      vim.split(selection, "\n")
    )
    resume_insert(bufnr, target, end_row + 1, start_col - #pattern + #selection)
    return
  end

  vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, vim.split(pattern .. selection .. pattern, "\n"))
  resume_insert(bufnr, target, end_row + 1, start_col + #pattern * 2 + #selection)
end

-- Resolve what to act on now and return a function that performs the toggle
-- later. Anything that picks a format asynchronously has to capture the target
-- up front, since the selection is gone once the picker takes over.
function M.prepare(pattern, opts)
  local bufnr = vim.api.nvim_get_current_buf()
  local target = capture_target(bufnr, opts)
  return function()
    apply_format(bufnr, pattern, target)
  end
end

local function toggle_format(pattern, opts)
  M.prepare(pattern, opts)()
end

function M.toggle_bold(opts)
  toggle_format("**", opts)
end

function M.toggle_italic(opts)
  toggle_format("*", opts)
end

function M.toggle_strikethrough(opts)
  toggle_format("~~", opts)
end

function M.toggle_inline_code(opts)
  toggle_format("`", opts)
end

return M
