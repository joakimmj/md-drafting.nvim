-- Buffer, cursor and window helpers shared by the modules. Rows are 0-indexed
-- where the API they wrap is, and named `lnum` where they are 1-indexed.
local M = {}

--- The directory the buffer's file sits in, falling back to the working
--- directory for a buffer that has no file yet. Resolving against the
--- document's own directory rather than any notion of a project root is what
--- lets a flat folder of notes work with nothing configured.
---@param bufnr integer Buffer id, or 0 for the current buffer
---@return string dir Absolute directory path, with no trailing separator
function M.document_dir(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    return vim.fn.getcwd()
  end

  return vim.fn.fnamemodify(name, ":h")
end

--- Where `target` sits relative to `from`, walking up with `..` when it is not
--- underneath it. Written this way rather than absolutely so a link keeps
--- working wherever the folder holding it is opened from.
---@param from string Absolute directory the path is written from
---@param target string Absolute path to write
---@return string path Relative path, no "./" prefix, "." for `from` itself
function M.relative_path(from, target)
  local from_parts = vim.split(vim.fs.normalize(from), "/", { trimempty = true })
  local target_parts = vim.split(vim.fs.normalize(target), "/", { trimempty = true })

  local shared = 0
  while shared < #from_parts and shared < #target_parts and from_parts[shared + 1] == target_parts[shared + 1] do
    shared = shared + 1
  end

  local parts = {}
  for _ = shared + 1, #from_parts do
    table.insert(parts, "..")
  end
  for index = shared + 1, #target_parts do
    table.insert(parts, target_parts[index])
  end

  if #parts == 0 then
    return "."
  end

  return table.concat(parts, "/")
end

--- The text of a single line.
---@param bufnr integer Buffer id, or 0 for the current buffer
---@param row integer 0-indexed row
---@return string line Line text, empty when the row is out of range
function M.line(bufnr, row)
  return vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
end

--- Whether the editor is in insert mode.
---@return boolean insert
function M.in_insert_mode()
  return vim.api.nvim_get_mode().mode:sub(1, 1) == "i"
end

--- The visual mode letter when one is active.
---@return string? mode One of "v", "V" or CTRL-V, or nil outside visual mode
local function visual_mode()
  return vim.api.nvim_get_mode().mode:sub(1, 1):match("[vV\22]")
end

--- The region to act on: the visual selection, or the range a user command was
--- given. Called from a mapping, with no opts, the current mode decides.
---@param bufnr integer Buffer id, or 0 for the current buffer
---@param opts? table Options a user command was called with
---@return integer[]? range 0-indexed { start_row, start_col, end_row, end_col },
---the end column exclusive, or nil when nothing is selected
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

--- The selected text, joined with newlines.
---@param bufnr integer Buffer id, or 0 for the current buffer
---@param opts? table Options a user command was called with
---@return string? text Selected text, or nil when nothing is selected
---@return integer[]? range The range it was read from, as M.selection returns it
function M.selected_text(bufnr, opts)
  local range = M.selection(bufnr, opts)
  if not range then
    return nil
  end
  return table.concat(vim.api.nvim_buf_get_text(bufnr, range[1], range[2], range[3], range[4], {}), "\n"), range
end

--- Where the word under the cursor ends. On whitespace the word before the
--- cursor is taken, or the one after it when the line starts with the gap.
---@param bufnr integer Buffer id, or 0 for the current buffer
---@param lnum integer 1-indexed row
---@param col integer 0-indexed column
---@return integer col 0-indexed column just past the word
function M.word_end(bufnr, lnum, col)
  local line = M.line(bufnr, lnum - 1)
  local pos = math.max(math.min(col + 1, #line), 1) -- 1-indexed character under the cursor

  if pos <= #line and line:sub(pos, pos):match("%s") then
    local back = pos - 1
    while back > 0 and line:sub(back, back):match("%s") do
      back = back - 1
    end

    if back > 0 then
      pos = back
    else
      while pos <= #line and line:sub(pos, pos):match("%s") do
        pos = pos + 1
      end
    end
  end

  while pos <= #line and line:sub(pos, pos):match("%S") do
    pos = pos + 1
  end

  return pos - 1
end

--- Put the cursor at a column and start typing there. Past the end of the line
--- there is no character to insert before, so append instead.
---@param bufnr integer Buffer id, or 0 for the current buffer
---@param win integer Window id, or 0 for the current window
---@param lnum integer 1-indexed row
---@param col integer 0-indexed column
function M.start_insert(bufnr, win, lnum, col)
  local line = M.line(bufnr, lnum - 1)
  if col >= #line then
    vim.api.nvim_win_set_cursor(win, { lnum, math.max(#line - 1, 0) })
    vim.cmd("startinsert!")
  else
    vim.api.nvim_win_set_cursor(win, { lnum, col })
    vim.cmd("startinsert")
  end
end

--- Ask for a value from the user.
---@param message string Prompt to display
---@param default? string Text to pre-fill the prompt with
---@return string? value The entered string, empty when left blank, nil when cancelled
function M.prompt(message, default)
  local ok, value = pcall(vim.fn.input, message, default or "")
  if not ok then
    return nil
  end
  return value
end

--- Make the buffer hold `lines`, writing only the one span where they differ.
--- Scattered changes merge into that span, so this is for a caller rewriting a
--- single region, not a general diff.
---@param bufnr integer Buffer id, or 0 for the current buffer
---@param lines string[] The lines the buffer should hold
function M.replace_lines(bufnr, lines)
  local old = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  local first = 1
  while first <= #old and first <= #lines and old[first] == lines[first] do
    first = first + 1
  end

  local last_old, last_new = #old, #lines
  while last_old >= first and last_new >= first and old[last_old] == lines[last_new] do
    last_old, last_new = last_old - 1, last_new - 1
  end

  -- Nothing between the two runs: the buffer already holds these lines.
  if first > last_old and first > last_new then
    return
  end

  vim.api.nvim_buf_set_lines(bufnr, first - 1, last_old, false, vim.list_slice(lines, first, last_new))
end

--- Root of the buffer's markdown syntax tree.
---@param bufnr integer Buffer id, or 0 for the current buffer
---@return TSNode? root Tree root, or nil once the caller has been told why not
function M.ts_root(bufnr)
  -- Before Neovim 0.12 a missing parser raises; from 0.12 on it comes back as
  -- `nil, err`. Fold the two into the second shape.
  local ok, parser, err = pcall(vim.treesitter.get_parser, bufnr, "markdown")
  if not ok then
    parser, err = nil, parser
  end

  if not parser then
    vim.notify(("md-drafting: no markdown treesitter parser: %s"):format(err or "unknown reason"), vim.log.levels.ERROR)
    return nil
  end

  local trees = parser:parse()
  if trees and trees[1] then
    return trees[1]:root()
  end

  vim.notify("md-drafting: could not parse the buffer as markdown", vim.log.levels.ERROR)
  return nil
end

return M
