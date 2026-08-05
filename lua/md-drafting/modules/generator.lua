local M = {}

local config = require("md-drafting.config")
local util = require("md-drafting.util")

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
    table.insert(quoted, "> [!" .. callout_type .. "]")
  end
  for _, line in ipairs(lines) do
    -- A blank line becomes a bare "> ".
    table.insert(quoted, line:match("^%s*$") and "> " or "> " .. line)
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
  local node = util.ts_root(bufnr):descendant_for_range(row - 1, col, row - 1, col)

  while node do
    if node:type() == "block_quote" then
      return (node:range())
    end
    node = node:parent()
  end
end

function M.generate_toc()
  local bufnr = vim.api.nvim_get_current_buf()

  -- Find existing TOC
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local toc_start, toc_end
  for i, line in ipairs(lines) do
    if string.find(line, "<!-- TOC -->", 1, true) then
      toc_start = i
    elseif string.find(line, "<!-- /TOC -->", 1, true) then
      toc_end = i
    end
  end

  local root = util.ts_root(bufnr)

  local query = vim.treesitter.query.parse("markdown", "(atx_heading) @heading")
  local toc = { "<!-- TOC -->" }

  for _, match, _ in query:iter_captures(root, bufnr, 0, -1) do
    local start_row, _, _, _ = match:range()
    -- if we have a toc, and the heading is inside it, skip
    if not (toc_start and toc_end and start_row + 1 >= toc_start and start_row + 1 <= toc_end) then
      local node_text = vim.treesitter.get_node_text(match, bufnr)
      local level = 0
      for i = 1, #node_text do
        if node_text:sub(i, i) == "#" then
          level = level + 1
        else
          break
        end
      end
      local header_text = node_text:match("#+%s*(.*)")
      if header_text then
        header_text = header_text:gsub("^%s+", ""):gsub("%s+$", "")
      end
      if header_text and header_text ~= "" then
        -- Underscores survive the slug, as they do in GitHub's anchors.
        local link_text = header_text:gsub("[^%w%s_-]", ""):gsub("%s", "-"):lower()
        table.insert(toc, string.rep("  ", level - 1) .. "- [" .. header_text .. "](#" .. link_text .. ")")
      end
    end
  end
  table.insert(toc, "<!-- /TOC -->")

  if toc_start and toc_end then
    vim.api.nvim_buf_set_lines(bufnr, toc_start - 1, toc_end, false, {}) -- Delete old TOC
    vim.api.nvim_buf_set_lines(bufnr, toc_start - 1, toc_start - 1, false, toc) -- Insert new TOC
  else
    vim.api.nvim_buf_set_lines(
      bufnr,
      vim.api.nvim_win_get_cursor(0)[1] - 1,
      vim.api.nvim_win_get_cursor(0)[1] - 1,
      false,
      toc
    )
  end
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
        -- Already inside a qoute block
        vim.api.nvim_buf_set_lines(bufnr, start_row, start_row, false, { "> [!" .. choice .. "]" })
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
