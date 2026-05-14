# New Room Content (Sub-project 4)

**Date:** 2026-05-14
**Sub-project:** 4 of 6

## Problem

The room catalogue covers 45 commands (17 beginner / 15 warrior / 13 ninja).
There are obvious gaps in every tier:

- **Beginner** has no rooms for file boundaries (`gg`/`G`), line boundaries
  (`0`/`$`/`^`), case toggle (`~`), or basic char deletion (`x`/`X`).
- **Warrior** has no indent operators, viewport jumps (`H`/`M`/`L`), scroll
  centering (`zz`/`zt`/`zb`), or line-number jump (`:N`).
- **Ninja** has no increment/decrement, `:sort`, normal-applied-to-range
  (`:'<,'>norm`), or jump-list navigation (`<C-o>`/`<C-i>`).

Each gap is a real vim concept a learner expects to see in a curriculum. The
goal is to fill 12 of them — four per tier — to round out coverage without
expanding into adjacent sub-projects (replay, SRS, sandbox).

## Goals

- Add 12 new rooms, four per tier, covering the concepts listed above.
- Each room loads via `rooms.load_tier()` with no schema-validation changes.
- One small schema extension (`bo` field) so the indent room can pin
  `shiftwidth=2 expandtab=true` independently of player config.
- `:VimmerMap` shows the new rooms naturally interleaved with existing ones;
  per-tier progress bars update; nothing breaks for in-progress players.

## Non-goals

- No alternates (`optimal_keystrokes_alternates`) for any new room. Primary
  path only. Alternates can be added later per-room if rigidity bites.
- No new highlight groups, screens, mechanics, or mutators.
- No boss rooms in this batch.
- No changes to existing rooms (IDs, ordering, content).
- No automated test of the `bo` field application path (touches `vim.bo`,
  nvim-only). Manual smoke covers it.
- No support for `<C-i>` in any room's optimal_keystrokes — it collides with
  the in-play Tab → freeze-powerup binding. Concept is taught via the tip
  text instead.

## Design

### Schema extension: `bo` field

Add optional `bo` field at room or boss-phase level. Type: table of
buffer-local option name → value. Applied by `play.lua` before installing
the key handler for a phase.

```lua
-- room or phase:
bo = { shiftwidth = 2, expandtab = true }
```

`play.lua` change inside `start_phase(phase_data)`, right after the play_buf
gets its initial lines:

```lua
local bo = phase_data.bo or room.bo
if type(bo) == "table" then
  for k, v in pairs(bo) do
    vim.bo[play_buf][k] = v
  end
end
```

Precedence: `phase_data.bo` (boss phase) wins over `room.bo` (regular room).
No room in this batch uses phase-level `bo`; the precedence is future-proofing.

`rooms.validate` is unchanged. `bo` is optional; the `type(bo) == "table"`
guard at apply time absorbs missing/wrong-shape values silently.

### The 12 rooms

All file paths are `lua/rooms/<tier>/<id>.lua`.

#### Beginner (no time_limit)

**B1 — `beginner_file_boundaries`** (pure nav)

```lua
return {
  id = "beginner_file_boundaries",
  tier = "beginner",
  command = "gg / G",
  title = "File Boundaries: gg, G",
  description = "gg jumps to the first line; G jumps to the last line",
  before_example = "|line 1\nline 5",
  after_example = "line 1\n|line 5",
  usage_tip = "G = last line. 5G = line 5. gg = first line. Faster than counting j.",
  start_text = "first line\nfiller\nfiller\nfiller\nlast line",
  target_text = "first line\nfiller\nfiller\nfiller\nlast line",
  base_xp = 45,
  optimal_keystrokes = { "G" },
}
```

**B2 — `beginner_line_boundaries`** (pure nav)

```lua
return {
  id = "beginner_line_boundaries",
  tier = "beginner",
  command = "0 / $ / ^",
  title = "Line Boundaries: 0, $, ^",
  description = "0 = column 0; $ = end of line; ^ = first non-blank char",
  before_example = "|    indented line ending here",
  after_example = "    indented line ending here|",
  usage_tip = "0 hits raw start. ^ skips leading whitespace. $ jumps to last char.",
  start_text = "    indented start    and trailing",
  target_text = "    indented start    and trailing",
  base_xp = 45,
  optimal_keystrokes = { "$" },
}
```

**B3 — `beginner_toggle_case`** (edit)

```lua
return {
  id = "beginner_toggle_case",
  tier = "beginner",
  command = "~",
  title = "Toggle Case: ~",
  description = "Flip case of char under cursor and advance",
  before_example = "|Hello",
  after_example = "hELLO|",
  usage_tip = "Press ~ repeatedly. With count: 5~ flips next 5 chars in one go.",
  start_text = "Hello",
  target_text = "hELLO",
  base_xp = 55,
  optimal_keystrokes = { "~", "~", "~", "~", "~" },
}
```

**B4 — `beginner_delete_char`** (edit, reuses `$` from B2)

```lua
return {
  id = "beginner_delete_char",
  tier = "beginner",
  command = "x",
  title = "Delete Char: x",
  description = "x deletes the char under the cursor; X deletes the char before",
  before_example = "vim is great|XXX",
  after_example = "vim is great|",
  usage_tip = "x deletes under cursor. X deletes BEFORE cursor. Combine with $ to trim trailing junk.",
  start_text = "vim is greatXXX",
  target_text = "vim is great",
  base_xp = 60,
  optimal_keystrokes = { "$", "x", "x", "x" },
}
```

#### Warrior (no time_limit unless noted)

**W1 — `warrior_indent`** (edit; only room in this batch using `bo`)

```lua
return {
  id = "warrior_indent",
  tier = "warrior",
  command = ">> / <<",
  title = "Indent: >>, <<",
  description = ">> indents the current line by one shiftwidth; << dedents",
  before_example = "|return 1",
  after_example = "  |return 1",
  usage_tip = "Repeat with . or use ranges: V}>  indents a paragraph.",
  start_text = "fn foo():\nreturn 1\nreturn 2",
  target_text = "fn foo():\n  return 1\n  return 2",
  bo = { shiftwidth = 2, expandtab = true },
  base_xp = 75,
  optimal_keystrokes = { "j", ">", ">", "j", ">", ">" },
}
```

**W2 — `warrior_viewport`** (pure nav)

```lua
return {
  id = "warrior_viewport",
  tier = "warrior",
  command = "H / M / L",
  title = "Viewport Jumps: H, M, L",
  description = "H = top of screen, M = middle, L = bottom",
  before_example = "|top visible row",
  after_example = "top visible row\n…\n|bottom visible row",
  usage_tip = "Jumps within the visible window — not the whole file. Quick when scrolling around.",
  start_text = "row 1\nrow 2\nrow 3\nrow 4\nrow 5\nrow 6\nrow 7",
  target_text = "row 1\nrow 2\nrow 3\nrow 4\nrow 5\nrow 6\nrow 7",
  base_xp = 70,
  optimal_keystrokes = { "L" },
}
```

**W3 — `warrior_scroll`** (pure nav)

```lua
return {
  id = "warrior_scroll",
  tier = "warrior",
  command = "zz / zt / zb",
  title = "Center View: zz, zt, zb",
  description = "zz centers cursor line; zt puts it at top; zb at bottom",
  before_example = "|line on cursor",
  after_example = "(window scrolls to center it)",
  usage_tip = "Great after a big jump (G, /search, gg). zz feels like re-anchoring.",
  start_text = "anchor 1\nanchor 2\nanchor 3\nanchor 4\nanchor 5",
  target_text = "anchor 1\nanchor 2\nanchor 3\nanchor 4\nanchor 5",
  base_xp = 70,
  optimal_keystrokes = { "z", "z" },
}
```

**W4 — `warrior_goto_line`** (pure nav)

```lua
return {
  id = "warrior_goto_line",
  tier = "warrior",
  command = ":N",
  title = "Goto Line: :N",
  description = "Type :NUMBER<CR> to jump to that line",
  before_example = "|line 1\n...\nline 7",
  after_example = "line 1\n...\n|line 7",
  usage_tip = ":7<CR> is the same as 7G. Pairs naturally with line numbers in the gutter.",
  start_text = "line 1\nline 2\nline 3\nline 4\nline 5\nline 6\nline 7",
  target_text = "line 1\nline 2\nline 3\nline 4\nline 5\nline 6\nline 7",
  base_xp = 75,
  optimal_keystrokes = { ":", "5", "\r" },
}
```

#### Ninja (time_limit on each)

**N1 — `ninja_inc_dec`** (edit; count-prefixed)

```lua
return {
  id = "ninja_inc_dec",
  tier = "ninja",
  command = "<C-a> / <C-x>",
  title = "Increment / Decrement: <C-a>, <C-x>",
  description = "Bump the next number on or after the cursor up (<C-a>) or down (<C-x>)",
  before_example = "version |1",
  after_example = "version |2",
  usage_tip = "Prefix a count: 5<C-a> adds 5. Scans forward from cursor on current line.",
  start_text = "build: 1\nstage: 1\ndeploy: 1",
  target_text = "build: 5\nstage: 5\ndeploy: 5",
  base_xp = 100,
  time_limit = 50,
  optimal_keystrokes = { "4", "\x01", "j", "4", "\x01", "j", "4", "\x01" },
}
```

**N2 — `ninja_sort`** (edit)

```lua
return {
  id = "ninja_sort",
  tier = "ninja",
  command = ":sort",
  title = "Sort Lines: :sort",
  description = "Sort lines in the buffer alphabetically (or numerically with n flag)",
  before_example = "banana\napple\ncherry",
  after_example = "apple\nbanana\ncherry",
  usage_tip = ":sort sorts whole file; visual+:sort sorts the selection. :sort! reverses. :sort u removes dupes.",
  start_text = "echo\nalpha\ndelta\nbravo\ncharlie",
  target_text = "alpha\nbravo\ncharlie\ndelta\necho",
  base_xp = 100,
  time_limit = 45,
  optimal_keystrokes = { ":", "s", "o", "r", "t", "\r" },
}
```

**N3 — `ninja_norm_range`** (edit; visual + ex-range)

```lua
return {
  id = "ninja_norm_range",
  tier = "ninja",
  command = ":'<,'>norm <cmd>",
  title = "Apply Normal to Selection: :norm",
  description = "Run a normal-mode sequence on every line in a visual selection",
  before_example = "alpha\nbeta",
  after_example = "alpha;\nbeta;",
  usage_tip = "V<motion> then :norm A;<CR> appends a char to many lines at once.",
  start_text = "red\ngreen\nblue\nyellow",
  target_text = "red;\ngreen;\nblue;\nyellow;",
  base_xp = 110,
  time_limit = 55,
  optimal_keystrokes = { "V", "G", ":", "n", "o", "r", "m", " ", "A", ";", "\r" },
}
```

**N4 — `ninja_jump_list`** (pure nav; `<C-i>` taught via tip only)

```lua
return {
  id = "ninja_jump_list",
  tier = "ninja",
  command = "<C-o> / <C-i>",
  title = "Jump History: <C-o>, <C-i>",
  description = "<C-o> jumps to older position in the jump list; <C-i> jumps to newer",
  before_example = "After /search or G, back-track without retyping",
  after_example = "Cursor returns to prior location",
  usage_tip = "Like browser back/forward. <C-i> = Tab; the play tab maps Tab to freeze powerup, so use <C-i> in your real editor.",
  start_text = "anchor top\nfiller\nfiller\nfiller\nfiller\nfiller\nanchor bottom",
  target_text = "anchor top\nfiller\nfiller\nfiller\nfiller\nfiller\nanchor bottom",
  base_xp = 95,
  time_limit = 30,
  optimal_keystrokes = { "G", "\x0f" },
}
```

### Tests

**No changes to `rooms.validate` semantics**, so existing `rooms_spec`
coverage carries.

**New spec block** appended to `tests/spec/rooms_spec.lua`:

```lua
describe("rooms.load_tier picks up new content rooms", function()
  local rooms = require("the-vimmer.rooms")

  before_each(function() rooms.clear_cache() end)

  local expected_new_ids = {
    "beginner_file_boundaries", "beginner_line_boundaries",
    "beginner_toggle_case",     "beginner_delete_char",
    "warrior_indent",           "warrior_viewport",
    "warrior_scroll",           "warrior_goto_line",
    "ninja_inc_dec",            "ninja_sort",
    "ninja_norm_range",         "ninja_jump_list",
  }

  it("validates and loads every new room", function()
    local found = {}
    for _, tier in ipairs({ "beginner", "warrior", "ninja" }) do
      for _, r in ipairs(rooms.load_tier(tier)) do
        found[r.id] = true
      end
    end
    for _, id in ipairs(expected_new_ids) do
      assert.is_true(found[id], "missing room: " .. id)
    end
  end)
end)
```

`bo` field application is not unit-testable headlessly (`vim.bo`). Manual
smoke covers it.

### Verification

- `busted` runs green (existing + new load-spec).
- `:VimmerMap` lists 21 beginner / 19 warrior / 17 ninja rooms (the 45
  existing + 12 new).
- Open each new room through the teach screen → play → win path. Edit rooms
  reach target via the optimal sequence; nav rooms accept the optimal
  keypress and resolve via text-equality on first scheduled check.
- W1 specifically: confirm `>>` inserts exactly 2 spaces of indent, not
  tabs and not 8 spaces. Proves `bo` field landed.
- N4: confirm Tab still triggers freeze powerup inside the play tab;
  confirm `<C-o>` operates as jumplist back.

### Edge cases

- `\x01` (Ctrl-A) and `\x0f` (Ctrl-O) in optimal_keystrokes — room files
  load via `dofile` inside Neovim (LuaJIT), where `\xHH` string escapes
  parse correctly. Not loaded by busted, so the Lua 5.1 escape limitation
  that affected `pad_row` in sub-project 6b does not apply here.
- N3 `:norm A;<CR>` — `:norm` implicitly appends Esc after the typed
  sequence, so the inserted `;` is committed and normal mode resumed
  without the player typing Esc explicitly.
- W1 indent — `bo` is buffer-local; it does not pollute the player's
  global config. Setting `expandtab=true` on a buffer overrides any
  global `noexpandtab` for this buffer only.
- B2 line-boundaries — the title advertises three commands (`0`/`$`/`^`)
  but the optimal path uses only `$`. Other two are taught via the tip
  text. Trade-off: smaller scope per room, learner reads the tip.
- N4 `<C-i>` exclusion — `<C-i>` is byte 0x09, identical to Tab. The
  play-tab Tab→freeze keymap (`play.lua:1046` in pre-6b layout, now
  `ui/play.lua` post-6b) intercepts it. Tip text flags the conflict;
  optimal sequence uses only `<C-o>`.
- N2 :sort behavior — Neovim's `:sort` is locale-aware by default. For
  pure ASCII test data (`alpha`, `bravo`, …) this is stable.
- N3 N1 N2 — all three rely on player typing a colon-prefix command. The
  game's `vim.on_key` handler captures every byte including the colon
  and the typed command chars; this is the same path the existing
  ninja `substitute` room uses (`lua/rooms/ninja/substitute.lua`).

## Open questions

None.
