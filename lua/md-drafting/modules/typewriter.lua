-- Typewriter scrolling: the line being written keeps a fixed height on screen
-- instead of the view scrolling under it.
local M = {}

local config = require("md-drafting.config")

local NAMESPACE = vim.api.nvim_create_namespace("MdDraftingTypewriter")
local FILLER_EXTMARK = 1

-- Keyed by buffer: this is switched on per document, so the same window can
-- hold it for one file and not another.
local active = {}

-- Guards against the scrolling below moving the cursor, which would fire
-- CursorMoved and land us back in here.
local centering = false

-- The screen row the cursor is held on. Row 1 is the top of the window.
local function target_row(height)
  local position = config.options.typewriter.position
  return math.max(1, math.min(math.floor(height * position) + 1, height))
end

-- Blank rows above the first line, enough to hold the cursor at `row` when the
-- document starts there. Nothing is written to the buffer: it is the user's own
-- document, which must not grow lines just because of how it is displayed.
local function apply_filler(bufnr, row)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  if row < 2 then
    pcall(vim.api.nvim_buf_del_extmark, bufnr, NAMESPACE, FILLER_EXTMARK)
    return
  end

  local blanks = {}
  for _ = 1, row - 1 do
    table.insert(blanks, { { "" } })
  end

  vim.api.nvim_buf_set_extmark(bufnr, NAMESPACE, 0, 0, {
    id = FILLER_EXTMARK,
    virt_lines = blanks,
    virt_lines_above = true,
  })
end

local function center()
  if centering then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local state = active[bufnr]
  if not state then
    return
  end

  centering = true

  local row = target_row(vim.api.nvim_win_get_height(0))
  if row ~= state.filler then
    apply_filler(bufnr, row)
    state.filler = row
  end

  -- Where the cursor really is. ':normal!' below runs in normal mode, which
  -- clamps the column to the last character -- past the end of a line, or on
  -- an empty one, that is not where insert mode was. Restoring it afterwards
  -- is what keeps typing from landing in the wrong place.
  local before = vim.fn.winsaveview()

  vim.cmd("normal! zz")
  local delta = vim.fn.winline() - row
  if delta > 0 then
    vim.cmd(("normal! %d\5"):format(delta))
  elseif delta < 0 then
    vim.cmd(("normal! %d\25"):format(-delta))
  end

  local after = vim.fn.winsaveview()
  after.lnum, after.col, after.coladd, after.curswant =
    before.lnum, before.col, before.coladd, before.curswant
  vim.fn.winrestview(after)

  centering = false
end

function M.is_enabled(bufnr)
  return active[bufnr or vim.api.nvim_get_current_buf()] ~= nil
end

function M.enable(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if active[bufnr] then
    return
  end

  local win = vim.api.nvim_get_current_win()

  active[bufnr] = {
    win = win,
    filler = nil,
    -- Both are window-local and both are ours while this is on, so they are
    -- saved and put back on the way out.
    scrolloff = vim.wo[win].scrolloff,
    smoothscroll = vim.wo[win].smoothscroll,
    group = vim.api.nvim_create_augroup("MdDraftingTypewriter" .. bufnr, { clear = true }),
  }

  -- 'scrolloff' would re-clamp the view straight after each adjustment, so the
  -- two cannot both be steering. 'smoothscroll' makes <C-e>/<C-y> move by
  -- screen row rather than whole buffer line, without which a wrapped line
  -- above the cursor makes the text jump as it is scrolled over.
  vim.wo[win].scrolloff = 0
  vim.wo[win].smoothscroll = true

  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "WinScrolled" }, {
    group = active[bufnr].group,
    buffer = bufnr,
    callback = center,
  })

  -- Rewriting every line drags the mark off the first one, so the blank rows
  -- are put back whenever the text changes. Moving the cursor cannot move them.
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = active[bufnr].group,
    buffer = bufnr,
    callback = function()
      local state = active[bufnr]
      if state then
        state.filler = nil
      end
      center()
    end,
  })

  center()
end

function M.disable(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local state = active[bufnr]
  if not state then
    return
  end
  active[bufnr] = nil

  pcall(vim.api.nvim_del_augroup_by_id, state.group)

  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_clear_namespace(bufnr, NAMESPACE, 0, -1)
  end

  if vim.api.nvim_win_is_valid(state.win) then
    vim.wo[state.win].scrolloff = state.scrolloff
    vim.wo[state.win].smoothscroll = state.smoothscroll
  end
end

function M.toggle(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if M.is_enabled(bufnr) then
    M.disable(bufnr)
  else
    M.enable(bufnr)
  end
end

return M
