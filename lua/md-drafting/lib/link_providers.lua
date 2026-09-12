-- Where a link or an image gets its target.
--
-- This plugin does not itself know what a link can point at beyond the files
-- around the document -- that knowledge lives in providers, registered through
-- the public API, so a dependent plugin sends links at its own targets instead
-- of reimplementing the feature to reach them.
local M = {}

local config = require("md-drafting.config")

--- A registered source of link targets.
---
--- `resolve(ctx, done)` is handed `ctx.kind` ("link" or "image") and `ctx.text`
--- (the label a selection supplied, when there was one) and answers
--- `done{ text = , path = }`, or `done(nil)` to abort. It answers through a
--- callback rather than by returning, since a provider is free to open a picker
--- of its own.
---@class MdDraftingLinkProvider
---@field label string Name the picker offers
---@field resolve fun(ctx: { kind: string, text: string? }, done: fun(link: { text: string?, path: string? }?))
---@field kinds? string[] Callers it is offered to; both when left out

---@type MdDraftingLinkProvider[]
local providers = {}

--- Add a provider, offered from then on by whichever callers its `kinds` name.
---@param provider MdDraftingLinkProvider Provider to register
function M.register(provider)
  table.insert(providers, provider)
end

--- The providers a caller may offer: the ones `link_providers.order` names
--- first, in that order, and the rest behind them in registration order. A
--- provider naming no `kinds` is offered to every caller.
---@param kind string Caller kind, "link" or "image"
---@return MdDraftingLinkProvider[] providers Providers for that kind
function M.for_kind(kind)
  local wanted = {}

  for index, provider in ipairs(providers) do
    if not provider.kinds or vim.tbl_contains(provider.kinds, kind) then
      table.insert(wanted, { provider = provider, index = index })
    end
  end

  local rank = {}
  for position, label in ipairs(config.options.link_providers.order) do
    rank[label] = position
  end

  -- Registration order breaks every tie, ordered or not: table.sort is not
  -- stable, so the order left over cannot be left to it.
  table.sort(wanted, function(a, b)
    local a_rank = rank[a.provider.label] or math.huge
    local b_rank = rank[b.provider.label] or math.huge

    if a_rank ~= b_rank then
      return a_rank < b_rank
    end

    return a.index < b.index
  end)

  return vim.tbl_map(function(entry)
    return entry.provider
  end, wanted)
end

--- The provider a caller named, by label or as the provider itself.
---@param wanted MdDraftingLinkProvider[] Providers offered for the kind
---@param kind string Caller kind, for the message when there is no match
---@param named string|MdDraftingLinkProvider Label, or the provider itself
---@return MdDraftingLinkProvider? provider Provider to use, or nil once the caller has been told why not
local function named_provider(wanted, kind, named)
  for _, provider in ipairs(wanted) do
    if provider == named or provider.label == named then
      return provider
    end
  end

  local name = type(named) == "table" and tostring(named.label) or tostring(named)
  vim.notify(("md-drafting: no link provider %q for %s targets"):format(name, kind), vim.log.levels.ERROR)
end

--- Ask which provider to use, and hand it to the callback. One provider is not
--- a choice, so no picker appears while only one is registered for the kind --
--- nor when the caller named the one it wants.
---@param kind string Caller kind, "link" or "image"
---@param callback fun(provider: MdDraftingLinkProvider) Called with the choice, not at all when there is none
---@param opts? table Options the caller was called with; `provider` names one outright
function M.pick(kind, callback, opts)
  local wanted = M.for_kind(kind)

  if #wanted == 0 then
    vim.notify(("md-drafting: no link provider for %s targets"):format(kind), vim.log.levels.ERROR)
    return
  end

  -- A caller naming a provider meant to skip the question, so a name matching
  -- nothing is an error rather than a reason to ask it after all.
  local named = opts and opts.provider
  if named then
    local provider = named_provider(wanted, kind, named)
    if provider then
      callback(provider)
    end
    return
  end

  if #wanted == 1 then
    callback(wanted[1])
    return
  end

  -- Labels, not the providers themselves: a picker is free to read an item
  -- table's fields as its own, and a provider's `resolve` is exactly the kind of
  -- name one claims -- snacks.nvim calls `item.resolve(item)` while rendering.
  -- The choice comes back by index, so two providers may share a label.
  local labels = vim.tbl_map(function(provider)
    return provider.label
  end, wanted)

  vim.ui.select(labels, { prompt = ("Insert %s from:"):format(kind) }, function(_, idx)
    if idx then
      callback(wanted[idx])
    end
  end)
end

return M
