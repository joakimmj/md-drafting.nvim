-- Walking the files around the document, one directory at a time.
--
-- Built on vim.ui.select like the rest of the plugin, so it is whatever picker
-- the user already runs. That costs the things a file picker of its own would
-- have -- a query, previews, key bindings -- so everything the browser can do
-- is an entry in the list instead: going up, toggling hidden files, and typing
-- a target the tree does not hold.
local M = {}

local util = require("md-drafting.lib.util")

-- Entries that are not files. Bracketed so they read apart from the names
-- around them, whatever a directory happens to hold, and offered before the
-- listing so they sit in the same place in every directory.
local UP = "../"
local SHOW_HIDDEN = "[Show hidden files]"
local HIDE_HIDDEN = "[Hide hidden files]"
-- A directory is a target in its own right, answered with by walking into it
-- and taking it. One entry among the actions rather than a second entry beside
-- every folder, which is what a listing of folders would double into.
local INSERT_DIR = "[Insert this folder]"

-- Whether dotfiles are listed, for as long as the session lasts. Hidden to
-- start: `.git`, `.obsidian` and a dependent plugin's own files are not what
-- someone is looking for, and the entry is there when they are.
local show_hidden = false

--- Names in the order a reader looks for them: case is not what someone
--- scanning a list sorts by, so `Notes.md` sits with `notes.md` rather than
--- ahead of every lowercase name. Case decides between two names that are
--- otherwise the same, which a directory can hold both of.
---@param a string Name
---@param b string Name
---@return boolean before
local function by_name(a, b)
  local lower_a, lower_b = a:lower(), b:lower()
  if lower_a == lower_b then
    return a < b
  end

  return lower_a < lower_b
end

--- What a directory holds, folders and files in one list: a name is looked for
--- where its name puts it, not in whichever half of the list its kind belongs
--- to. The trailing separator a folder is shown with says which is which.
---@param dir string Absolute directory path
---@param filter? fun(name: string): boolean Which files to list; all of them when left out
---@return { name: string, is_dir: boolean }[] entries Names in reading order
local function entries(dir, filter)
  local listed = {}

  for _, name in ipairs(vim.fn.readdir(dir)) do
    if show_hidden or name:sub(1, 1) ~= "." then
      local is_dir = vim.fn.isdirectory(dir .. "/" .. name) == 1
      if is_dir or not filter or filter(name) then
        table.insert(listed, { name = name, is_dir = is_dir })
      end
    end
  end

  table.sort(listed, function(a, b)
    return by_name(a.name, b.name)
  end)

  return listed
end

--- Browse for a target, one directory at a time, until something is chosen or
--- the picker is abandoned.
---@param opts { dir: string, typed_prompt: string, filter?: fun(name: string): boolean, insert_dirs?: boolean }
---@param done fun(answer: { path: string?, text: string? }?) Absolute `path`, verbatim `text`, or nil when abandoned
function M.browse(opts, done)
  local dir = vim.fs.normalize(opts.dir)
  local listed = entries(dir, opts.filter)

  -- What each entry means, by the label the picker shows, so the answer needs
  -- no parsing back out of it.
  local choices, action = {}, {}

  local function offer(label, handler)
    table.insert(choices, label)
    action[label] = handler
  end

  offer(("[%s…]"):format(opts.typed_prompt), function()
    local text = util.prompt(("%s: "):format(opts.typed_prompt))
    if not text or text == "" then
      return done(nil)
    end
    done({ text = text })
  end)

  if opts.insert_dirs then
    offer(INSERT_DIR, function()
      done({ path = dir })
    end)
  end

  offer(show_hidden and HIDE_HIDDEN or SHOW_HIDDEN, function()
    show_hidden = not show_hidden
    M.browse(opts, done)
  end)

  local parent = vim.fs.dirname(dir)
  if parent ~= dir then
    offer(UP, function()
      M.browse(vim.tbl_extend("force", opts, { dir = parent }), done)
    end)
  end

  for _, entry in ipairs(listed) do
    local path = dir .. "/" .. entry.name
    if entry.is_dir then
      offer(entry.name .. "/", function()
        M.browse(vim.tbl_extend("force", opts, { dir = path }), done)
      end)
    else
      offer(entry.name, function()
        done({ path = path })
      end)
    end
  end

  vim.ui.select(choices, { prompt = ("%s:"):format(vim.fn.fnamemodify(dir, ":~")) }, function(choice)
    if not choice then
      return done(nil)
    end
    action[choice]()
  end)
end

return M
