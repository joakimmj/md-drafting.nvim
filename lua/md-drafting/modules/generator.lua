local M = {}

local config = require("md-drafting.config")
local section = require("md-drafting.lib.section")
local syntax = require("md-drafting.syntax")
local util = require("md-drafting.lib.util")

-- Quote a run of lines, optionally under a callout header. A callout is a block
-- quote with a "> [!TYPE]" line on top of it.
local function quote_range(bufnr, range, callout_type)
  local start_line, end_line
  if range then
    start_line, end_line = range[1] + 1, range[3] + 1
  else
    start_line = vim.api.nvim_win_get_cursor(0)[1]
    end_line = start_line
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
  local empty = #lines == 1 and lines[1]:match("^%s*$") ~= nil

  local quoted = {}
  if callout_type then
    table.insert(quoted, syntax.format_callout(callout_type))
  end
  for _, line in ipairs(lines) do
    table.insert(quoted, syntax.format_quote(line))
  end

  vim.api.nvim_buf_set_lines(bufnr, start_line - 1, end_line, false, quoted)

  -- Land after the "> " on the last line written.
  if empty then
    util.start_insert(bufnr, 0, start_line + #quoted - 1, 2)
  end
end

-- Row the block quote around the cursor starts on, 0-indexed, or nil when the
-- cursor is not inside one.
local function enclosing_block_quote_row(bufnr)
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local root = util.ts_root(bufnr)
  if not root then
    return nil
  end

  local node = root:descendant_for_range(row - 1, col, row - 1, col)

  while node do
    if node:type() == "block_quote" then
      return (node:range())
    end
    node = node:parent()
  end
end

function M.generate_toc()
  local bufnr = vim.api.nvim_get_current_buf()

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local toc_start, toc_end = section.find(lines, "TOC")

  local root = util.ts_root(bufnr)
  if not root then
    return
  end

  local query = vim.treesitter.query.parse("markdown", "(atx_heading) @heading")
  local body = {}

  for _, match, _ in query:iter_captures(root, bufnr, 0, -1) do
    local row = match:range() + 1
    -- A heading the last run wrote into the table of contents is not one of the
    -- document's own headings.
    if not (toc_start and toc_end and row >= toc_start and row <= toc_end) then
      local level, heading = syntax.parse_heading(vim.treesitter.get_node_text(match, bufnr))
      if heading and heading ~= "" then
        local entry = syntax.format_link(heading, syntax.format_anchor(heading))
        table.insert(body, syntax.format_list_item(string.rep("  ", level - 1) .. "- ", nil, entry))
      end
    end
  end

  -- With no markers in the file yet, the table of contents is written where the
  -- cursor is: the writer is the one who knows where it belongs.
  section.regenerate(bufnr, "TOC", body, { at = vim.api.nvim_win_get_cursor(0)[1] })
end

function M.add_table()
  local cols = tonumber(util.prompt("Enter number of columns: "))
  if not cols or cols <= 0 then
    vim.notify("md-drafting: enter a positive number of columns", vim.log.levels.ERROR)
    return
  end

  local blank, delimiter = {}, {}
  for _ = 1, cols do
    table.insert(blank, "")
    table.insert(delimiter, "---")
  end

  local tbl = {
    syntax.format_table_row(blank),
    syntax.format_table_row(delimiter),
    syntax.format_table_row(blank),
  }

  local bufnr = vim.api.nvim_get_current_buf()
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  vim.api.nvim_buf_set_lines(bufnr, cursor_line - 1, cursor_line - 1, false, tbl)

  -- Start typing in the first header cell.
  util.start_insert(bufnr, 0, cursor_line, 2)
end

local function link_target(bufnr, opts)
  local text, range = util.selected_text(bufnr, opts)

  if range and text and text ~= "" then
    return {
      text = text,
      start_line = range[1],
      start_col = range[2],
      end_line = range[3],
      end_col = range[4],
    }
  end

  local lnum, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = util.line(bufnr, lnum - 1)
  local at = util.word_end(bufnr, lnum, col)
  local trailing = line:sub(at + 1):match("^%s*$") and #line or at

  return {
    pad = at > 0, -- a space clear of the word it follows
    start_line = lnum - 1,
    start_col = at,
    end_line = lnum - 1,
    end_col = trailing,
  }
end

local function link_text(target)
  if target.text then
    if target.text:find("\n") then
      vim.notify("md-drafting: select the link text on a single line", vim.log.levels.ERROR)
      return nil
    end
    return target.text
  end

  local text = util.prompt("Enter link text: ")
  if not text or text == "" then
    return nil
  end

  return text
end

local function insert_link(bufnr, target, link)
  if target.pad then
    link = " " .. link
  end

  vim.api.nvim_buf_set_text(bufnr, target.start_line, target.start_col, target.end_line, target.end_col, { link })
  vim.api.nvim_win_set_cursor(0, { target.start_line + 1, target.start_col + #link })
end

function M.prepare_link(opts)
  local bufnr = vim.api.nvim_get_current_buf()
  local target = link_target(bufnr, opts)

  return function()
    local text = link_text(target)
    if not text then
      return
    end

    local url = util.prompt("Enter URL: ")
    if not url or url == "" then
      return
    end

    insert_link(bufnr, target, syntax.format_link(text, url))
  end
end

function M.add_link(opts)
  M.prepare_link(opts)()
end

function M.add_image()
  local alt_text = util.prompt("Enter image alt text: ")
  if not alt_text then
    return
  end
  local url = util.prompt("Enter image source: ")

  if not url or url == "" then
    vim.notify("md-drafting: enter an image source", vim.log.levels.ERROR)
    return
  end

  local image = syntax.format_image(alt_text, url)
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]

  vim.api.nvim_buf_set_lines(vim.api.nvim_get_current_buf(), cursor_line - 1, cursor_line - 1, false, { image })
end

-- `[ref]: url`.
local REF_DEFINITION = "^%[[^%]]*%]:%s"

-- Append a definition to the end of the buffer
local function append_definition(bufnr, definition)
  local last = vim.api.nvim_buf_get_lines(bufnr, -2, -1, false)[1] or ""
  local lines = { "", definition }

  if last:match("^%s*$") or last:match(REF_DEFINITION) then
    lines = { definition }
  end

  vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, lines)
end

function M.add_footnote()
  local bufnr = vim.api.nvim_get_current_buf()
  local text = util.prompt("Enter footnote text: ")

  if not text or text == "" then
    vim.notify("md-drafting: enter the footnote text", vim.log.levels.ERROR)
    return
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local max_num = 0
  for _, line in ipairs(lines) do
    for _, footnote in ipairs(syntax.parse_footnote_refs(line)) do
      if footnote.n > max_num then
        max_num = footnote.n
      end
    end
  end
  local footnote_num = max_num + 1

  local footnote_marker = syntax.format_footnote_ref(footnote_num)
  local lnum, col = unpack(vim.api.nvim_win_get_cursor(0))
  local at = util.word_end(bufnr, lnum, col)

  vim.api.nvim_buf_set_text(bufnr, lnum - 1, at, lnum - 1, at, { footnote_marker })
  vim.api.nvim_win_set_cursor(0, { lnum, at + #footnote_marker })

  append_definition(bufnr, syntax.format_footnote_definition(footnote_num, text))
end

function M.add_code_block()
  local lang = util.prompt("Enter programming language (default: empty): ")
  if not lang then
    return
  end

  local code_block = {
    syntax.format_code_fence(lang),
    "",
    syntax.format_code_fence(),
  }
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  vim.api.nvim_buf_set_lines(bufnr, cursor_line - 1, cursor_line - 1, false, code_block)

  -- Start typing on the blank line between the fences.
  util.start_insert(bufnr, 0, cursor_line + 1, 0)
end

-- Resolve the target now, apply later, so the actions menu can read the
-- selection before its picker throws visual mode away.
function M.prepare_block_quote(opts)
  local bufnr = vim.api.nvim_get_current_buf()
  local range = util.selection(bufnr, opts)

  return function()
    quote_range(bufnr, range, nil)
  end
end

function M.add_block_quote(opts)
  M.prepare_block_quote(opts)()
end

local function reference_exists(bufnr, ref_name)
  local root = util.ts_root(bufnr)
  if not root then
    return false
  end

  local query = vim.treesitter.query.parse("markdown", "(link_reference_definition) @def")
  local label = syntax.format_link_label(ref_name)

  for _, node in query:iter_captures(root, bufnr, 0, -1) do
    for child in node:iter_children() do
      if child:type() == "link_label" and vim.treesitter.get_node_text(child, bufnr) == label then
        return true
      end
    end
  end

  return false
end

function M.prepare_reference_style_link(opts)
  local bufnr = vim.api.nvim_get_current_buf()
  local target = link_target(bufnr, opts)

  return function()
    local text = link_text(target)
    if not text then
      return
    end

    local ref_name = util.prompt("Enter reference name (default: link text): ", text)
    if not ref_name then
      return
    end
    if ref_name == "" then
      ref_name = text
    end

    local url
    if not reference_exists(bufnr, ref_name) then
      url = util.prompt("Enter URL: ")
      if not url or url == "" then
        return
      end
    end

    insert_link(bufnr, target, syntax.format_reference_link(text, ref_name))

    if url then
      append_definition(bufnr, syntax.format_reference_definition(ref_name, url))
    end
  end
end

function M.add_reference_style_link(opts)
  M.prepare_reference_style_link(opts)()
end

-- Resolve the target now, apply later. Both vim.ui.select and the actions menu
-- are asynchronous, so the selection has to be read before either opens.
function M.prepare_callout(opts)
  local bufnr = vim.api.nvim_get_current_buf()
  local range = util.selection(bufnr, opts)

  return function()
    vim.ui.select(config.options.callout_types, { prompt = "Select callout type:" }, function(choice)
      if not choice then
        return
      end

      if range then
        quote_range(bufnr, range, choice)
        return
      end

      local start_row = enclosing_block_quote_row(bufnr)
      if start_row then
        -- Already inside a block quote: give it a header instead.
        vim.api.nvim_buf_set_lines(bufnr, start_row, start_row, false, { syntax.format_callout(choice) })
        return
      end

      quote_range(bufnr, nil, choice)
    end)
  end
end

function M.add_callout(opts)
  M.prepare_callout(opts)()
end

return M
