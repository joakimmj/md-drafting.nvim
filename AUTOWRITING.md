# md-drafting.nvim — Future Ideas

Reconstructed from an earlier design discussion (a document called
`md-drafting-autowriting.md`, since deleted) that never made it into the
completed plugin. None of this is implemented. It's scoped here against
`md-drafting.nvim` as it actually exists today, not as it was designed back
then — some of the mechanics below would need to be rebuilt against the
current `api`, `format`/`generator`/`jump` modules, and section system rather
than the ones originally sketched.

## A design tension to resolve first

Everything here reacts to typing — `Enter`, `Tab`, paste — rather than being
invoked. The finished v1 plugin's stance is that **presentation mode is the
one feature allowed to own keymaps**; focus mode was deliberately built
*without* one even though it easily could have been (`toggle()` is its whole
API). Every idea below would be a second, third, and fourth exception to
that rule, all at once, and all inside the buffer the user is normally
editing in — a much larger collision surface than a modal view.

The original design handled this with an opt-in-per-feature, off-by-default,
always-fall-back-to-normal-behavior pattern. That's a reasonable answer, but
it's still a bigger philosophical carve-out than the one exception v1
shipped with, and worth deciding on deliberately rather than by default
before building any of this.

## The ideas

**Continue list item on `Enter`.** Pressing `Enter` inside a list item
starts the next one at the same level automatically, rather than leaving a
bare line. Falls back to normal `Enter` outside a list.

**Renumber an ordered list.** After inserting or deleting an item in a
numbered list, the rest of the list's numbers correct themselves. Passive —
runs on text-change, not on a keypress — so it doesn't touch the keymap
question above at all.

**Smart paste — URL onto a selection.** Pasting a URL while text is visually
selected wraps the selection as a link to that URL instead of overwriting
it. Falls back to a normal paste when there's no selection or the clipboard
isn't a URL.

**Smart paste — image from clipboard.** Pasting image data (a screenshot)
saves it into the configured local-file directory and inserts an image link,
instead of pasting nothing. OS-dependent on the clipboard tool available
(`wl-paste`, `xclip`, `pngpaste`), which would need its own detection layer.

**Tab through table cells.** Inside a table, `Tab`/`Shift-Tab` move between
cells rather than doing whatever `Tab` normally does, realigning the
column on cell-exit. Tabbing out of the last cell in the last row adds a new
row.

**Fold cycling on a heading.** `Tab` on a heading line cycles that
heading's own fold state (collapsed → children shown → fully expanded);
`Shift-Tab` does the same for the whole buffer. Would sit on Neovim's native
folding rather than tracking visibility separately. This is also the one
idea that directly overlaps existing v1 territory — `jump.next("heading")`
already exists — so it's worth deciding whether folding belongs next to
jumping or is a genuinely separate concern.

**Link picker on a trigger sequence.** Typing a configurable sequence (`[[`
by default) opens the same provider picker `add_link` already uses,
replacing the typed characters with the resolved link on selection. This one
would actually slot in cleanly against the *current* plugin, since
`add_link`'s provider system (Part 2 §3) already exists and this would just
be a second way to reach it.

## What's genuinely still relevant

Of these seven, **link-picker-on-trigger** is the strongest candidate to
revisit first — it reuses a mechanism that already shipped rather than
needing new infrastructure, and it's arguably the single highest-friction
gap left in the current writing flow (reaching for a picker versus just
typing `[[`). The two **smart-paste** ideas are close behind: genuinely
useful, low risk of keymap collision since paste is a narrower surface than
`Enter`/`Tab`. **List continuation and renumbering** are plain quality-of-life
and low-risk. **Table tab-navigation** and **fold cycling** are the two
that claim the most contested keys (`Tab` is already the most
loaded key in a markdown buffer) and would benefit most from the keymap
question above being settled first.
