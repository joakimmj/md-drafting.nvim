-- Moving the cursor to the next or previous occurrence of a markdown construct
local M = {}

local config = require("md-drafting.config")
local syntax = require("md-drafting.syntax")
local util = require("md-drafting.lib.util")

--- The constructs a jump can move between.
---@enum JumpTarget
M.TARGETS = {
  LINK = "link",
  REFERENCE_LINK = "reference_link",
  HEADING = "heading",
  TASK = "task",
  NOT_DONE_TASK = "not_done_task",
  CODE_BLOCK = "code_block",
  TABLE = "table",
  THEMATIC_BREAK = "thematic_break",
  FOOTNOTE = "footnote",
}

--- Whether one position comes before another in the document.
---@param a integer[] Position as { row, col }
---@param b integer[] Position compared against
---@return boolean before Whether a comes before b
local function precedes(a, b)
  return a[1] < b[1] or (a[1] == b[1] and a[2] < b[2])
end

--- Several position lists merged into one, in document order.
---@param ... integer[][] Position lists
---@return integer[][] positions Positions in document order
local function in_document_order(...)
  local merged = {}

  for _, positions in ipairs({ ... }) do
    vim.list_extend(merged, positions)
  end

  table.sort(merged, precedes)
  return merged
end

--- Every position a line-based target answers with, in document order.
---@param bufnr integer Buffer to scan
---@param positions_in fun(line: string): integer[] Columns the line matches at, or none
---@return integer[][] positions Positions the target answers with
local function scan_lines(bufnr, positions_in)
  local found = {}

  for row, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
    for _, col in ipairs(positions_in(line)) do
      table.insert(found, { row, col })
    end
  end

  return found
end

--- The first position of every node of that type, in document order.
---@param bufnr integer Buffer to scan
---@param node_type string Treesitter node type
---@return integer[][] positions Positions the target answers with
local function scan_nodes(bufnr, node_type)
  local root = util.ts_root(bufnr)
  if not root then
    return {}
  end

  local found = {}
  local query = vim.treesitter.query.parse("markdown", ("(%s) @node"):format(node_type))

  for _, node in query:iter_captures(root, bufnr, 0, -1) do
    local row, col = node:range()
    table.insert(found, { row + 1, col })
  end

  return found
end

-- Adding a target is an entry here; the name is the one a caller, a command and
-- a picker all use.
---@type { name: string, find: fun(bufnr: integer): integer[][] }[]
local TARGETS = {
  {
    name = M.TARGETS.LINK,
    find = function(bufnr)
      return scan_lines(bufnr, function(line)
        local columns = {}
        for _, link in ipairs(syntax.parse_links(line)) do
          table.insert(columns, link.col)
        end
        return columns
      end)
    end,
  },
  {
    name = M.TARGETS.REFERENCE_LINK,
    find = function(bufnr)
      -- A link and its definition are two halves of one construct.
      local links = scan_lines(bufnr, function(line)
        local columns = {}
        for _, link in ipairs(syntax.parse_reference_links(line)) do
          table.insert(columns, link.col)
        end
        return columns
      end)

      return in_document_order(links, scan_nodes(bufnr, "link_reference_definition"))
    end,
  },
  {
    name = M.TARGETS.HEADING,
    find = function(bufnr)
      return scan_nodes(bufnr, "atx_heading")
    end,
  },
  {
    name = M.TARGETS.TASK,
    find = function(bufnr)
      return scan_lines(bufnr, function(line)
        local prefix, marker = syntax.parse_list_item(line)
        if marker then
          return { #prefix }
        end
        return {}
      end)
    end,
  },
  {
    name = M.TARGETS.NOT_DONE_TASK,
    -- Which markers count as not done is `task_states`, so a configured cycle
    -- is jumped by the same markers it is toggled through.
    find = function(bufnr)
      return scan_lines(bufnr, function(line)
        local prefix, marker = syntax.parse_list_item(line)
        if prefix and syntax.marker_state(marker, config.options.task_states) == "not_done" then
          return { #prefix }
        end
        return {}
      end)
    end,
  },
  {
    name = M.TARGETS.CODE_BLOCK,
    find = function(bufnr)
      return scan_nodes(bufnr, "fenced_code_block")
    end,
  },
  {
    name = M.TARGETS.TABLE,
    find = function(bufnr)
      return scan_nodes(bufnr, "pipe_table")
    end,
  },
  {
    name = M.TARGETS.THEMATIC_BREAK,
    find = function(bufnr)
      return scan_lines(bufnr, function(line)
        if syntax.parse_thematic_break(line) then
          return { 0 }
        end
        return {}
      end)
    end,
  },
  {
    name = M.TARGETS.FOOTNOTE,
    find = function(bufnr)
      return scan_lines(bufnr, function(line)
        local columns = {}
        for _, footnote in ipairs(syntax.parse_footnote_refs(line)) do
          table.insert(columns, footnote.col)
        end
        return columns
      end)
    end,
  },
}

--- The target names, in the order the menu offers them.
---@return string[] names Target names
function M.target_names()
  local names = {}
  for _, target in ipairs(TARGETS) do
    table.insert(names, target.name)
  end
  return names
end

--- The target of that name, or nil once the caller has been told there is none.
---@param name string Target name, one of M.TARGETS
---@return table? target Target, a name and a find(bufnr)
local function target_named(name)
  for _, target in ipairs(TARGETS) do
    if target.name == name then
      return target
    end
  end

  vim.notify(
    ("md-drafting: no jump target %q, one of: %s"):format(tostring(name), table.concat(M.target_names(), ", ")),
    vim.log.levels.ERROR
  )
end

--- Move to the first match on the given side of the cursor.
---@param name string One of M.TARGETS
---@param backward boolean Whether to move to the match before the cursor
local function jump(name, backward)
  local target = target_named(name)
  if not target then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local positions = target.find(bufnr)
  if #positions == 0 then
    vim.notify(("md-drafting: no %s in this buffer"):format((name:gsub("_", " "))), vim.log.levels.INFO)
    return
  end

  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local cursor = { row, col }
  local found

  for index = 1, #positions do
    -- Backward walks the same list from the end.
    local position = positions[backward and (#positions - index + 1) or index]

    -- Strictly on the side asked for, never where the cursor already is.
    local first, second = position, cursor
    if not backward then
      first, second = cursor, position
    end

    if precedes(first, second) then
      found = position
      break
    end
  end

  -- Nothing on that side: wrap.
  found = found or positions[backward and #positions or 1]

  vim.api.nvim_win_set_cursor(0, found)
end

--- Move to the next occurrence of a construct, wrapping to the first.
---@param target string One of M.TARGETS
function M.next(target)
  jump(target, false)
end

--- Move to the previous occurrence of a construct, wrapping to the last.
---@param target string One of M.TARGETS
function M.previous(target)
  jump(target, true)
end

return M
