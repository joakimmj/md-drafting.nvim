-- The windowing mechanics behind the plugin's full-screen views.

local M = {}

local BACKDROP_ZINDEX = 40
local CONTENT_ZINDEX = 50

-- Hidden while a view is open. Both are global rather than window-local, so
-- they have to be saved and put back manually.
local GLOBALS = { "laststatus", "showtabline" }

-- Applied before the caller's own overrides.
local BASE_WIN_OPTS = {
  number = false,
  relativenumber = false,
  signcolumn = "no",
}

-- Only one view can be open at a time: a second would save the first's already
-- modified globals and restore the wrong values on the way out.
local active = nil

--- Close a window if it is still there.
---@param win? integer Window id
local function close_window(win)
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end
end

-- Highlights
local highlights = {}

--- Define a highlight group and remember it across `:colorscheme`.
---@param name string Highlight group name
---@param value vim.api.keyset.highlight Group definition
function M.define_highlight(name, value)
  highlights[name] = value
  vim.api.nvim_set_hl(0, name, vim.tbl_extend("force", value, { default = true }))
end

-- ':colorscheme' clears every group, including these, so they have to be
-- defined again afterwards.
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("MdDraftingFocusedViewHighlight", { clear = true }),
  callback = function()
    for name, value in pairs(highlights) do
      vim.api.nvim_set_hl(0, name, vim.tbl_extend("force", value, { default = true }))
    end
  end,
})

-- Default highlight groups for all focused views.
M.define_highlight("MdDraftingHeader", { link = "StatusLine" })
M.define_highlight("MdDraftingNormal", { link = "Normal" })
M.define_highlight("MdDraftingBackdrop", { link = "Normal" })

--- Centered geometry for the content float. A width below 1 is a fraction of the
--- terminal, anything else a column count; either way it is clamped to the
--- terminal, so a narrow one degrades to full width instead of overflowing.
---@param width? number Width in columns, or a fraction of the terminal
---@return vim.api.keyset.win_config config Window config
local function geometry(width)
  local columns = vim.o.columns

  width = width or columns
  if width > 0 and width < 1 then
    width = math.floor(columns * width)
  end
  width = math.max(1, math.min(math.floor(width), columns))

  return {
    relative = "editor",
    width = width,
    height = math.max(1, vim.o.lines - vim.o.cmdheight),
    row = 0,
    col = math.floor((columns - width) / 2),
  }
end

--- Where each window goes. With no gap asked for, the heading is the content
--- window's own winbar and there is nothing else to place.
---@param opts FocusedViewOpts View options
---@return { content: table, heading: table? } places Window configs
local function layout(opts)
  local base = geometry(opts.width)
  local gap = opts.header and (opts.header_gap or 0) or 0

  if gap < 1 then
    return { content = base }
  end

  -- The heading window is its winbar plus `gap` empty rows below it. A winbar
  -- is drawn inside its window's own height rather than on top of it, so it
  -- has to be counted in.
  local used = gap + 1

  return {
    heading = vim.tbl_extend("force", base, { height = used }),
    content = vim.tbl_extend("force", base, {
      row = base.row + used,
      height = math.max(1, base.height - used),
    }),
  }
end

--- 'winhighlight' is a single option holding every remapping for a window, so the
--- caller's entries and the view's own have to be merged by key rather than one
--- overwriting the other.
---@param existing? string The option's current value
---@param owned string[][] Entries the view owns, as { from, to } pairs
---@return string winhighlight The merged option
local function winhighlight(existing, owned)
  local taken, entries = {}, {}

  for _, pair in ipairs(owned) do
    taken[pair[1]] = true
  end

  -- Keys can repeat in the option -- style = "minimal" alone emits
  -- "EndOfBuffer:" twice -- so the first of each is kept and the rest dropped.
  for entry in (existing or ""):gmatch("[^,]+") do
    local key = entry:match("^([^:]+):")
    if key and not taken[key] then
      taken[key] = true
      table.insert(entries, entry)
    end
  end

  for _, pair in ipairs(owned) do
    table.insert(entries, pair[1] .. ":" .. pair[2])
  end

  return table.concat(entries, ",")
end

--- A heading laid out as left / center / right.
---
--- Winbar content is parsed as a statusline, so "%" in text that came from the
--- document has to be escaped or it is read as an item; "%=" between the
--- sections is what spreads them out.
---@param sections { left?: string | { text: string, hl: string? }, center?: string | { text: string, hl: string? }, right?: string | { text: string, hl: string? } } Sections, each a string or a table giving it a highlight group of its own
---@return string winbar Heading, as a statusline expression
function M.header_line(sections)
  local rendered = {}

  for _, name in ipairs({ "left", "center", "right" }) do
    local value = sections[name] or ""
    local section = type(value) == "string" and { text = value } or value

    local text = (section.text or ""):gsub("%%", "%%%%")
    if section.hl then
      -- "%*" restores the bar's own group, so one section's color does not
      -- bleed into those after it.
      text = ("%%#%s#%s%%*"):format(section.hl, text)
    end

    table.insert(rendered, text)
  end

  -- A space at either end keeps the text off the edge of the window.
  return " " .. table.concat(rendered, "%=") .. " "
end

---@class FocusedViewOpts
---@field buf integer Buffer to show; the caller owns it, scratch or real
---@field width? number Content width, see geometry()
---@field header? fun(): string Heading, rendered into the winbar
---@field header_events? string[] Events that re-render the heading
---@field header_hl? string Highlight group for the heading strip
---@field header_gap? integer Blank rows between the heading and the content
---@field normal_hl? string Highlight group for the content window itself
---@field backdrop? string|false Highlight group for the margins, false for none
---@field win_opts? table<string, any> Window-local overrides, over BASE_WIN_OPTS
---@field on_close? fun() Called once, as the view is torn down

---@class FocusedViewHandle
---@field win integer? Content window, nil once it has been closed
---@field buf integer Buffer being shown
---@field closed boolean Whether the view has been torn down
---@field cursor fun(): integer[]? Cursor position in the view
---@field refresh_header fun() Re-render the heading
---@field close fun() Tear the view down and restore what it took

--- Open a full-screen view: a centered content window, an optional heading
--- above it, and a backdrop filling the margins. Only one can be open at a
--- time, so opening a second closes the first.
---
--- The colors are named as groups rather than set through win_opts.winhighlight
--- so that callers never have to build that string, and so the view keeps hold
--- of the keys its own styling depends on.
---@param opts FocusedViewOpts View options
---@return FocusedViewHandle handle The open view
function M.open(opts)
  if active then
    active.close()
  end

  local saved = {}
  for _, name in ipairs(GLOBALS) do
    saved[name] = vim.o[name]
  end
  vim.o.laststatus = 0
  vim.o.showtabline = 0

  local places = layout(opts)
  local backdrop_win, heading_win

  local function normal_pairs()
    if not opts.normal_hl then
      return {}
    end
    return { { "Normal", opts.normal_hl }, { "NormalNC", opts.normal_hl } }
  end

  local function header_pairs()
    if not opts.header_hl then
      return {}
    end
    return { { "WinBar", opts.header_hl }, { "WinBarNC", opts.header_hl } }
  end

  if opts.backdrop then
    local backdrop_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[backdrop_buf].bufhidden = "wipe"

    backdrop_win = vim.api.nvim_open_win(backdrop_buf, false, {
      relative = "editor",
      width = vim.o.columns,
      height = places.content.height + places.content.row,
      row = 0,
      col = 0,
      style = "minimal",
      focusable = false,
      zindex = BACKDROP_ZINDEX,
    })
    vim.wo[backdrop_win].winhighlight = ("Normal:%s,NormalNC:%s"):format(opts.backdrop, opts.backdrop)
  end

  local win = vim.api.nvim_open_win(
    opts.buf,
    true,
    vim.tbl_extend("force", places.content, { style = "minimal", zindex = CONTENT_ZINDEX })
  )

  for name, value in pairs(BASE_WIN_OPTS) do
    vim.wo[win][name] = value
  end
  for name, value in pairs(opts.win_opts or {}) do
    vim.wo[win][name] = value
  end

  if places.heading then
    -- An empty buffer, so every row of it renders blank: style = "minimal"
    -- blanks the end-of-buffer region too, leaving nothing but the gap.
    local heading_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[heading_buf].bufhidden = "wipe"

    heading_win = vim.api.nvim_open_win(
      heading_buf,
      false,
      vim.tbl_extend("force", places.heading, {
        style = "minimal",
        focusable = false,
        zindex = CONTENT_ZINDEX,
      })
    )

    -- The gap reads as the top of the page rather than as margin, so it takes
    -- the content window's colors, not the backdrop's.
    local owned = normal_pairs()
    vim.list_extend(owned, header_pairs())
    vim.wo[heading_win].winhighlight = winhighlight(nil, owned)
  end

  -- Whichever window carries the winbar is the one the heading is drawn on.
  local header_win = heading_win or win

  local content_owned = normal_pairs()
  if not heading_win then
    vim.list_extend(content_owned, header_pairs())
  end
  vim.wo[win].winhighlight = winhighlight(vim.wo[win].winhighlight, content_owned)

  local group = vim.api.nvim_create_augroup("MdDraftingFocusedView", { clear = true })
  local handle = { win = win, buf = opts.buf, closed = false }

  -- Where the cursor is in the view, for a caller showing a real buffer that
  -- wants to carry the position back to wherever else the buffer is open. Read
  -- from the last known position once the window has gone.
  function handle.cursor()
    if handle.win and vim.api.nvim_win_is_valid(handle.win) then
      return vim.api.nvim_win_get_cursor(handle.win)
    end
    return handle.last_cursor
  end

  function handle.refresh_header()
    if opts.header and vim.api.nvim_win_is_valid(header_win) then
      vim.wo[header_win].winbar = opts.header()
    end
  end

  function handle.close()
    if handle.closed then
      return
    end
    handle.closed = true
    active = nil

    pcall(vim.api.nvim_del_augroup_by_id, group)

    if opts.on_close then
      opts.on_close()
    end

    close_window(handle.win)
    close_window(heading_win)
    close_window(backdrop_win)

    for name, value in pairs(saved) do
      vim.o[name] = value
    end
  end

  vim.api.nvim_create_autocmd("VimResized", {
    group = group,
    callback = function()
      local resized = layout(opts)

      if handle.win and vim.api.nvim_win_is_valid(handle.win) then
        vim.api.nvim_win_set_config(handle.win, resized.content)
      end
      if heading_win and resized.heading and vim.api.nvim_win_is_valid(heading_win) then
        vim.api.nvim_win_set_config(heading_win, resized.heading)
      end
      if backdrop_win and vim.api.nvim_win_is_valid(backdrop_win) then
        vim.api.nvim_win_set_config(backdrop_win, {
          relative = "editor",
          width = vim.o.columns,
          height = resized.content.height + resized.content.row,
          row = 0,
          col = 0,
        })
      end
    end,
  })

  -- The view can also be dismissed by closing its window directly, with :q or
  -- anything else. Without this the backdrop would be left behind and the
  -- globals never restored. The window is already going away by the time this
  -- runs, so it is dropped from the handle rather than closed again, and the
  -- rest is deferred out of the closing window's context.
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    pattern = tostring(win),
    callback = function()
      if vim.api.nvim_win_is_valid(win) then
        handle.last_cursor = vim.api.nvim_win_get_cursor(win)
      end
      handle.win = nil
      vim.schedule(handle.close)
    end,
  })

  if opts.header_events and #opts.header_events > 0 then
    vim.api.nvim_create_autocmd(opts.header_events, {
      group = group,
      buffer = opts.buf,
      callback = function()
        handle.refresh_header()
      end,
    })
  end

  handle.refresh_header()
  active = handle

  return handle
end

return M
