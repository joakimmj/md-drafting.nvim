local M = {}

-- Text of a single 0-indexed line, empty string when out of range.
function M.line(bufnr, row)
  return vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
end

function M.in_insert_mode()
  return vim.api.nvim_get_mode().mode:sub(1, 1) == "i"
end

-- The visual mode letter (v, V or CTRL-V) when one is active, else nil.
local function visual_mode()
  return vim.api.nvim_get_mode().mode:sub(1, 1):match("[vV\22]")
end

-- The region to act on, as 0-indexed { start_row, start_col, end_row, end_col }
-- with an exclusive end column, or nil when nothing is selected.
function M.selection(bufnr, opts)
  local visual = visual_mode()
  local start_row, start_col, end_row, end_col

  if visual then
    local anchor = vim.fn.getpos("v")
    local cursor = vim.fn.getpos(".")
    start_row, start_col, end_row, end_col = anchor[2], anchor[3], cursor[2], cursor[3]
    if start_row > end_row or (start_row == end_row and start_col > end_col) then
      start_row, start_col, end_row, end_col = end_row, end_col, start_row, start_col
    end
    start_row, start_col, end_row = start_row - 1, start_col - 1, end_row - 1

    if visual == "V" then
      start_col, end_col = 0, #M.line(bufnr, end_row)
    end
  elseif opts and (opts.range or 0) > 0 then
    local start_pos = vim.api.nvim_buf_get_mark(bufnr, "<")
    local end_pos = vim.api.nvim_buf_get_mark(bufnr, ">")
    start_row, start_col, end_row, end_col = start_pos[1] - 1, start_pos[2], end_pos[1] - 1, end_pos[2] + 1
  else
    return nil
  end

  return { start_row, start_col, end_row, math.min(end_col, #M.line(bufnr, end_row)) }
end

-- Put the cursor at a column and start typing there. Past the end of the line
-- there is no character to insert before, so append instead.
function M.start_insert(bufnr, win, row, col)
  local line = M.line(bufnr, row - 1)
  if col >= #line then
    vim.api.nvim_win_set_cursor(win, { row, math.max(#line - 1, 0) })
    vim.cmd("startinsert!")
  else
    vim.api.nvim_win_set_cursor(win, { row, col })
    vim.cmd("startinsert")
  end
end

return M
