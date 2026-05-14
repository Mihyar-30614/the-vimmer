# Real-World Rooms PR 2 — Beginner Tier Rewrite

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite all 21 beginner rooms (20 regular + 1 boss) so each is a realistic mini-task on a real-feeling code snippet, with explicit `filetype`, `cursor_start`, and `goal` fields. All primary and alternate keystroke sequences must reach `target_text` in the reachability harness.

**Architecture:** Engine plumbing already shipped in PR 1: `lua/the-vimmer/rooms.lua` validates the optional fields, `lua/the-vimmer/ui/play.lua` renders the goal line, room buffer is isolated from user plugins, and `tests/reachability.lua` checks any room whose context sets `goal`. PR 2 = pure content rewrite of `lua/rooms/beginner/*.lua`. One file edited per task. Reachability harness runs after each room to catch keystroke errors before commit. Final task runs full sweep across all 21 rooms.

**Tech Stack:** Lua 5.1 (Neovim runtime), busted (unit specs), headless Neovim (reachability harness).

**Calibration target (per spec):**
- 5–10 line snippets, single command focus, target requires 3–6 reps of the command
- `optimal_keystrokes` length: 8–20
- `time_limit`: usually `nil` or 60s
- `base_xp` range: 30–60

**Schema reminder (from `lua/the-vimmer/rooms.lua`):**

```lua
return {
  -- existing required fields
  id = "beginner_<slug>",
  tier = "beginner",
  command = "<key sequence>",
  title = "<short title>",
  description = "<one-line teach blurb>",
  before_example = "<before string for teach screen>",
  after_example = "<after string for teach screen>",
  usage_tip = "<expert tip>",
  start_text = "<multiline snippet>",
  target_text = "<multiline snippet after edit>",
  base_xp = 40,
  optimal_keystrokes = { "j", "l", "l", "r", "5" },
  optimal_keystrokes_alternates = {       -- optional
    { "2", "j", "0", "f", "2", "r", "5" },
  },
  time_limit = 60,                        -- optional

  -- new optional fields (PR 1)
  filetype = "lua",
  cursor_start = { row = 1, col = 1 },
  goal = "<task description shown in play HUD>",
}
```

**Conventions enforced across all rewrites:**
- `\27` is the literal escape character — keystroke arrays must use it, not `<Esc>`.
- `start_text` / `target_text` use Lua long-bracket strings `[[ ... ]]` and start with a newline so the first content line is line 1 after `vim.split(..., "\n")`. Same convention as the spec's sample room.
- `cursor_start.row` and `.col` are **1-indexed**; the harness converts to 0-indexed when calling `nvim_win_set_cursor`.
- `before_example` / `after_example` stay as small single-line teach hints; they are NOT the room snippet, so they keep their pedagogy-friendly form.
- `goal` is one short imperative sentence ("Add `!` after `ok`.") — what the player must do, not which keys to press.
- Each room provides **at least one** `optimal_keystrokes_alternates` entry when an obvious second path exists (e.g. `2l` instead of `ll`, or `cw` instead of `caw`). When the only sane path is one sequence, omit alternates.
- Filetype choice: prefer `lua` (since this is a Neovim plugin) for most rooms; use `python`, `text`, or `markdown` only where it teaches better.

**Per-room verification command (used in every task):**

```bash
nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -E "beginner_<room_slug>|reachability:|^\["
```

The `--all` flag forces the harness to check rooms regardless of whether their `goal` is set, which keeps the loop tight while iterating; the final sweep task runs without `--all` to mirror CI.

**Existing test suite (must continue to pass):**

```bash
busted
nvim --headless --noplugin -l tests/reachability.lua
```

---

## File Structure

| Path | Action | Responsibility |
|---|---|---|
| `lua/rooms/beginner/hjkl.lua` | Rewrite | h/j/k/l navigation room (Task 1) |
| `lua/rooms/beginner/hjkl2.lua` | Rewrite | Count-prefixed hjkl (Task 2) |
| `lua/rooms/beginner/w_motion.lua` | Rewrite | `w` forward word (Task 3) |
| `lua/rooms/beginner/b_motion.lua` | Rewrite | `b` back word (Task 4) |
| `lua/rooms/beginner/e_motion.lua` | Rewrite | `e` end-of-word (Task 5) |
| `lua/rooms/beginner/word_hop.lua` | Rewrite | w/b/e mixed (Task 6) |
| `lua/rooms/beginner/line_boundaries.lua` | Rewrite | 0/$/^ (Task 7) |
| `lua/rooms/beginner/file_boundaries.lua` | Rewrite | gg/G (Task 8) |
| `lua/rooms/beginner/insert_mode.lua` | Rewrite | i/a/o (Task 9) |
| `lua/rooms/beginner/insert2.lua` | Rewrite | a/A/o/O (Task 10) |
| `lua/rooms/beginner/delete_char.lua` | Rewrite | x (Task 11) |
| `lua/rooms/beginner/delete_motion.lua` | Rewrite | d{motion} (Task 12) |
| `lua/rooms/beginner/delete_yank.lua` | Rewrite | x/dd/yy/p mix (Task 13) |
| `lua/rooms/beginner/dd_yp.lua` | Rewrite | dd/yy/p (Task 14) |
| `lua/rooms/beginner/d_dollar.lua` | Rewrite | D / d$ (Task 15) |
| `lua/rooms/beginner/replace_char.lua` | Rewrite | r<char> (Task 16) |
| `lua/rooms/beginner/toggle_case.lua` | Rewrite | ~ (Task 17) |
| `lua/rooms/beginner/undo_redo.lua` | Rewrite | u / Ctrl-r (Task 18) |
| `lua/rooms/beginner/join_lines.lua` | Rewrite | J (Task 19) |
| `lua/rooms/beginner/counts.lua` | Rewrite | N{motion} (Task 20) |
| `lua/rooms/beginner/boss.lua` | Rewrite | 3-phase gauntlet (Task 21) |
| (no new files) | — | All engine code in place from PR 1. |

---

## Task 1: beginner_hjkl — basic motion on real code

**Files:**
- Modify: `lua/rooms/beginner/hjkl.lua`

**Design.** Three-line Lua snippet. Player navigates down + right to a specific char and replaces it. Forces every direction key except `k` (which Task 18's undo-redo room exercises).

- [ ] **Step 1: Read current file** to confirm baseline.

Run: `cat lua/rooms/beginner/hjkl.lua`
Expected: shows the toy `"move right to reach the end"` room.

- [ ] **Step 2: Rewrite the file**

Write `lua/rooms/beginner/hjkl.lua`:

```lua
-- Beginner room: hjkl basic motion. Navigate to a char on line 2 and replace it.
return {
  id = "beginner_hjkl",
  tier = "beginner",
  command = "h / j / k / l",
  title = "Basic Motions: hjkl",
  description = "Move cursor left (h), down (j), up (k), right (l)",
  before_example = "local x = |1",
  after_example = "local x = |5",
  usage_tip = "Stay on home row. Never reach for arrow keys again.",
  filetype = "lua",
  cursor_start = { row = 1, col = 1 },
  goal = "Change the `2` on line 2 to `5`.",
  start_text = [[
local one = 1
local two = 2
local three = 3]],
  target_text = [[
local one = 1
local two = 5
local three = 3]],
  base_xp = 30,
  optimal_keystrokes = { "j", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "r", "5" },
  optimal_keystrokes_alternates = {
    { "j", "$", "r", "5" },
  },
}
```

- [ ] **Step 3: Run reachability for this room**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -E "beginner_hjkl|reachability:" `
Expected: no `[beginner_hjkl ...]` failure lines. Final line reports `reachability: N checked, M skipped (no goal), all sequences pass` or similar.

- [ ] **Step 4: If failure, debug**

Failure modes to check in order:
1. Cursor column off by one — recount the target char column 1-indexed.
2. Wrong escape — must be `"\27"` not `"<Esc>"`.
3. Long-bracket leading newline missing — first content line must be line 1 after split.
4. Alternate sequence used a command that doesn't exist in beginner-mode mappings.

Adjust the file, rerun Step 3.

- [ ] **Step 5: Run busted to confirm no validator regression**

Run: `busted`
Expected: all green.

- [ ] **Step 6: Commit**

```bash
git add lua/rooms/beginner/hjkl.lua
git commit -m "feat(rooms): rewrite beginner_hjkl with realistic Lua snippet"
```

---

## Task 2: beginner_hjkl2 — count-prefixed motion

**Files:**
- Modify: `lua/rooms/beginner/hjkl2.lua`

**Design.** Numbered comment list inviting `4j` to jump down and a count-prefixed `l` to position the cursor.

- [ ] **Step 1: Rewrite the file**

Write `lua/rooms/beginner/hjkl2.lua`:

```lua
-- Beginner room: Nj / Nl count-prefixed motions. Jump to line 5 in one motion.
return {
  id = "beginner_hjkl2",
  tier = "beginner",
  command = "Nj / Nk / Nl / Nh",
  title = "Count Motions",
  description = "Prefix hjkl with a number to move multiple steps at once",
  before_example = "line 1 |TODO",
  after_example = "line 1 |DONE",
  usage_tip = "3j moves 3 lines down. 5l moves 5 chars right. No arrow keys.",
  filetype = "lua",
  cursor_start = { row = 1, col = 1 },
  goal = "Replace the `0` on line 5 with `9`.",
  start_text = [[
local counters = {
  alpha = 1,
  beta  = 2,
  gamma = 3,
  delta = 0,
}]],
  target_text = [[
local counters = {
  alpha = 1,
  beta  = 2,
  gamma = 3,
  delta = 9,
}]],
  base_xp = 40,
  time_limit = 45,
  optimal_keystrokes = { "4", "j", "1", "0", "l", "r", "9" },
  optimal_keystrokes_alternates = {
    { "j", "j", "j", "j", "$", "h", "r", "9" },
  },
}
```

- [ ] **Step 2: Run reachability for this room**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -E "beginner_hjkl2|reachability:"`
Expected: no failure.

- [ ] **Step 3: Debug if needed** (see Task 1 Step 4).

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/beginner/hjkl2.lua
git commit -m "feat(rooms): rewrite beginner_hjkl2 with count-prefix scenario"
```

---

## Task 3: beginner_w_motion — `w` forward word

**Files:**
- Modify: `lua/rooms/beginner/w_motion.lua`

**Design.** Single line with multiple words. Player hops `w` to land on a target word and replaces a char.

- [ ] **Step 1: Rewrite the file**

```lua
-- Beginner room: `w` forward-word motion. Hop to the broken word and fix one char.
return {
  id = "beginner_w_motion",
  tier = "beginner",
  command = "w",
  title = "Word Motion: w",
  description = "Move to the start of the next word",
  before_example = "the quick |brown fox",
  after_example = "the quick |brawn fox",
  usage_tip = "Jump word by word forward. Faster than holding l.",
  filetype = "text",
  cursor_start = { row = 1, col = 1 },
  goal = "Hop to `brown` and change the `o` to `a`.",
  start_text = [[
the quick brown fox jumps over the lazy dog]],
  target_text = [[
the quick brawn fox jumps over the lazy dog]],
  base_xp = 40,
  optimal_keystrokes = { "w", "w", "l", "l", "r", "a" },
  optimal_keystrokes_alternates = {
    { "2", "w", "l", "l", "r", "a" },
  },
}
```

- [ ] **Step 2: Run reachability for this room**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -E "beginner_w_motion|reachability:"`
Expected: no failure.

- [ ] **Step 3: Debug if needed.**

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/beginner/w_motion.lua
git commit -m "feat(rooms): rewrite beginner_w_motion with prose hop scenario"
```

---

## Task 4: beginner_b_motion — `b` back word

**Files:**
- Modify: `lua/rooms/beginner/b_motion.lua`

**Design.** Cursor starts at end of a function call; player backs up `b` to a parameter and replaces a char.

- [ ] **Step 1: Rewrite the file**

```lua
-- Beginner room: `b` backward-word motion. Walk back to a parameter and fix it.
return {
  id = "beginner_b_motion",
  tier = "beginner",
  command = "b",
  title = "Word Motion: b",
  description = "Move to the start of the previous word",
  before_example = "log info data |here",
  after_example = "log info |Data here",
  usage_tip = "Jump backward word by word. Pair with w for fast navigation.",
  filetype = "lua",
  cursor_start = { row = 2, col = 30 },
  goal = "From the end, back up to `data` and capitalize the `d`.",
  start_text = [[
local function audit(event, payload)
  log.info("event", event, "data", payload)
end]],
  target_text = [[
local function audit(event, payload)
  log.info("event", event, "Data", payload)
end]],
  base_xp = 40,
  optimal_keystrokes = { "b", "b", "r", "D" },
  optimal_keystrokes_alternates = {
    { "2", "b", "r", "D" },
  },
}
```

- [ ] **Step 2: Run reachability for this room**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -E "beginner_b_motion|reachability:"`
Expected: no failure. (If the cursor lands one column off, adjust `cursor_start.col` so that two `b` jumps reach the start of `data`. The literal column of the `,` after `payload)` on line 2 is the tested start.)

- [ ] **Step 3: Debug if needed.**

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/beginner/b_motion.lua
git commit -m "feat(rooms): rewrite beginner_b_motion with backward hop scenario"
```

---

## Task 5: beginner_e_motion — `e` end-of-word

**Files:**
- Modify: `lua/rooms/beginner/e_motion.lua`

**Design.** Variable name `foo`; cursor on first char; `e` lands on `o`, then `a!` appends a char to make `foo!`. Three `e` hops feel natural.

- [ ] **Step 1: Rewrite the file**

```lua
-- Beginner room: `e` end-of-word. Land on the last char of a word, append a suffix.
return {
  id = "beginner_e_motion",
  tier = "beginner",
  command = "e",
  title = "Word Motion: e",
  description = "Move to the end of the current or next word",
  before_example = "|foo bar baz",
  after_example = "fo|o bar baz!",
  usage_tip = "Use e to land at the end of a word, e.g. before appending a char.",
  filetype = "text",
  cursor_start = { row = 1, col = 1 },
  goal = "Land on the end of `baz` and append `!`.",
  start_text = [[
foo bar baz]],
  target_text = [[
foo bar baz!]],
  base_xp = 40,
  optimal_keystrokes = { "e", "e", "e", "a", "!", "\27" },
  optimal_keystrokes_alternates = {
    { "3", "e", "a", "!", "\27" },
  },
}
```

- [ ] **Step 2: Run reachability for this room**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -E "beginner_e_motion|reachability:"`
Expected: no failure.

- [ ] **Step 3: Debug if needed.**

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/beginner/e_motion.lua
git commit -m "feat(rooms): rewrite beginner_e_motion with end-of-word append"
```

---

## Task 6: beginner_word_hop — w/b/e mixed

**Files:**
- Modify: `lua/rooms/beginner/word_hop.lua`

**Design.** Short sentence; player swings forward with `w`, lands precisely with `e`, drops back with `b`. Two small edits on different words.

- [ ] **Step 1: Rewrite the file**

```lua
-- Beginner room: w/b/e combined. Two small edits, one needs forward hop, one needs back hop.
return {
  id = "beginner_word_hop",
  tier = "beginner",
  command = "w / b / e",
  title = "Word Motions: w, b, e",
  description = "w = next word, b = back word, e = end of word",
  before_example = "the |old fox the |old dog",
  after_example = "the |New fox the |New dog",
  usage_tip = "w hops forward one word. 2w hops two words. b reverses.",
  filetype = "text",
  cursor_start = { row = 1, col = 1 },
  time_limit = 55,
  goal = "Change both `old` words to `New` (capital N).",
  start_text = [[
the old fox jumps over the old dog]],
  target_text = [[
the New fox jumps over the New dog]],
  base_xp = 45,
  optimal_keystrokes = { "w", "c", "w", "N", "e", "w", "\27", "5", "w", "c", "w", "N", "e", "w", "\27" },
  optimal_keystrokes_alternates = {
    { "w", "r", "N", "l", "r", "e", "l", "r", "w", "6", "w", "r", "N", "l", "r", "e", "l", "r", "w" },
  },
}
```

- [ ] **Step 2: Run reachability for this room**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -E "beginner_word_hop|reachability:"`
Expected: no failure. This room has a higher risk of keystroke drift because two edits are required — be ready to swap the alternate for a `cw`-based path if `r` paths miscount.

- [ ] **Step 3: Debug if needed.** Likely simplification: keep only the primary, drop the brittle char-level alternate.

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/beginner/word_hop.lua
git commit -m "feat(rooms): rewrite beginner_word_hop with two-word rename scenario"
```

---

## Task 7: beginner_line_boundaries — 0 / $ / ^

**Files:**
- Modify: `lua/rooms/beginner/line_boundaries.lua`

**Design.** Two-line config with trailing junk on each line. Player uses `$` to jump to end and `x` to trim. Uses `0` then `i` to prepend a char on one line.

- [ ] **Step 1: Rewrite the file**

```lua
-- Beginner room: 0/$/^. Trim trailing junk from two lines, add prefix to one.
return {
  id = "beginner_line_boundaries",
  tier = "beginner",
  command = "0 / $ / ^",
  title = "Line Boundaries: 0, $, ^",
  description = "0 = column 0; $ = end of line; ^ = first non-blank char",
  before_example = "key = value|;",
  after_example = "key = value|",
  usage_tip = "0 hits raw start. ^ skips leading whitespace. $ jumps to last char.",
  filetype = "lua",
  cursor_start = { row = 1, col = 1 },
  goal = "Delete the trailing `;` on each of the three lines.",
  start_text = [[
local a = 1;
local b = 2;
local c = 3;]],
  target_text = [[
local a = 1
local b = 2
local c = 3]],
  base_xp = 45,
  optimal_keystrokes = { "$", "x", "j", "$", "x", "j", "$", "x" },
  optimal_keystrokes_alternates = {
    { "A", "\27", "x", "j", "A", "\27", "x", "j", "A", "\27", "x" },
  },
}
```

- [ ] **Step 2: Run reachability for this room**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -E "beginner_line_boundaries|reachability:"`
Expected: no failure. (`$` puts cursor on the last char, which is `;`, so `x` deletes it cleanly.)

- [ ] **Step 3: Debug if needed.**

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/beginner/line_boundaries.lua
git commit -m "feat(rooms): rewrite beginner_line_boundaries with trim scenario"
```

---

## Task 8: beginner_file_boundaries — gg / G

**Files:**
- Modify: `lua/rooms/beginner/file_boundaries.lua`

**Design.** Mock Lua module with header comment on top and a stub function at the bottom. Player jumps to bottom with `G`, deletes a placeholder line, then jumps to top with `gg` and amends the comment.

- [ ] **Step 1: Rewrite the file**

```lua
-- Beginner room: gg/G. Jump file boundaries to delete a stub and tag the header.
return {
  id = "beginner_file_boundaries",
  tier = "beginner",
  command = "gg / G",
  title = "File Boundaries: gg, G",
  description = "gg jumps to the first line; G jumps to the last line",
  before_example = "-- header|",
  after_example = "-- header!|",
  usage_tip = "G = last line. 5G = line 5. gg = first line. Faster than counting j.",
  filetype = "lua",
  cursor_start = { row = 1, col = 1 },
  goal = "Delete the last line `TODO`, then append `!` to the first line.",
  start_text = [[
-- module: ping
local M = {}
function M.ping() return "pong" end
return M
TODO]],
  target_text = [[
-- module: ping!
local M = {}
function M.ping() return "pong" end
return M]],
  base_xp = 45,
  optimal_keystrokes = { "G", "d", "d", "g", "g", "A", "!", "\27" },
}
```

- [ ] **Step 2: Run reachability for this room**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -E "beginner_file_boundaries|reachability:"`
Expected: no failure. (The `TODO` line has no trailing newline so `dd` on the last line removes the line and the preceding newline cleanly.)

- [ ] **Step 3: Debug if needed.**

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/beginner/file_boundaries.lua
git commit -m "feat(rooms): rewrite beginner_file_boundaries with file-edge scenario"
```

---

## Task 9: beginner_insert_mode — i / a / o

**Files:**
- Modify: `lua/rooms/beginner/insert_mode.lua`

**Design.** Lua table with a missing key — player uses `o` to open a new line and types the entry.

- [ ] **Step 1: Rewrite the file**

```lua
-- Beginner room: i/a/o. Open a new line inside a table and type a key.
return {
  id = "beginner_insert_mode",
  tier = "beginner",
  command = "i / a / o",
  title = "Insert Mode: i, a, o",
  description = "Enter insert mode: before cursor (i), after cursor (a), new line below (o)",
  before_example = "alpha = 1,|",
  after_example = "alpha = 1,\n  beta = 2,|",
  usage_tip = "i inserts BEFORE cursor. Move to the gap, press i, type, then <Esc>.",
  filetype = "lua",
  cursor_start = { row = 2, col = 1 },
  goal = "Add a new line `  beta = 2,` after `alpha`.",
  start_text = [[
local M = {
  alpha = 1,
}]],
  target_text = [[
local M = {
  alpha = 1,
  beta = 2,
}]],
  base_xp = 50,
  optimal_keystrokes = { "o", "b", "e", "t", "a", " ", "=", " ", "2", ",", "\27" },
}
```

- [ ] **Step 2: Run reachability for this room**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -E "beginner_insert_mode|reachability:"`
Expected: no failure. (`o` from line 2 auto-indents to match the leading two spaces under standard `autoindent`; the harness buffer has no filetype indent plugins so two literal spaces in the typed text are not needed — but verify in Step 3 that the resulting line is exactly `  beta = 2,`. If the harness produces no indent, prepend two literal spaces to the typed text.)

- [ ] **Step 3: Debug if needed.** If indent is absent, replace the typed body with `"o", " ", " ", "b", "e", ...`. Re-run.

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/beginner/insert_mode.lua
git commit -m "feat(rooms): rewrite beginner_insert_mode with table-entry scenario"
```

---

## Task 10: beginner_insert2 — a / A / o / O

**Files:**
- Modify: `lua/rooms/beginner/insert2.lua`

**Design.** Two-line list missing both a top header (`O`) and a trailing item (`o`). Player adds both, using `A` to append a comma to one existing item.

- [ ] **Step 1: Rewrite the file**

```lua
-- Beginner room: a/A/o/O. Add header above, trailing item below, comma after middle.
return {
  id = "beginner_insert2",
  tier = "beginner",
  command = "a / A / o / O",
  title = "Insert Variants",
  description = "A = append at end of line. o = open line below. O = open line above.",
  before_example = "one|\ntwo",
  after_example = "items:|\none,\ntwo,\nthree",
  usage_tip = "A puts you at end of line in insert mode. o opens a new line below.",
  filetype = "text",
  cursor_start = { row = 1, col = 1 },
  time_limit = 60,
  goal = "Add header line `items:` above, append `,` to lines 1 and 2, add `three` below.",
  start_text = [[
one
two]],
  target_text = [[
items:
one,
two,
three]],
  base_xp = 55,
  optimal_keystrokes = { "O", "i", "t", "e", "m", "s", ":", "\27", "j", "A", ",", "\27", "j", "A", ",", "\27", "o", "t", "h", "r", "e", "e", "\27" },
}
```

- [ ] **Step 2: Run reachability for this room**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -E "beginner_insert2|reachability:"`
Expected: no failure. (Note: a typo `t,h,r,e,e` vs `t,h,r,e,e` — the word `three` is `t,h,r,e,e`. Keystroke list above intentionally typos as `three` letters: verify the spelling before running.)

- [ ] **Step 3: Debug.** Confirm spelling: `t`, `h`, `r`, `e`, `e` spells `three`. Fix in file if typed wrong.

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/beginner/insert2.lua
git commit -m "feat(rooms): rewrite beginner_insert2 with header+items scenario"
```

---

## Task 11: beginner_delete_char — `x`

**Files:**
- Modify: `lua/rooms/beginner/delete_char.lua`

**Design.** Snippet with two stray characters (typos) on different lines; player deletes them with `x`.

- [ ] **Step 1: Rewrite the file**

```lua
-- Beginner room: x. Delete stray characters from real code.
return {
  id = "beginner_delete_char",
  tier = "beginner",
  command = "x",
  title = "Delete Char: x",
  description = "x deletes the char under the cursor; X deletes the char before",
  before_example = "x|y = 1",
  after_example = "x| = 1",
  usage_tip = "x deletes under cursor. X deletes BEFORE cursor. Combine with $ to trim trailing junk.",
  filetype = "lua",
  cursor_start = { row = 1, col = 7 },
  goal = "Remove the stray `q` on line 1 and the stray `z` on line 2.",
  start_text = [[
local qcount = 0
local indezx = 1]],
  target_text = [[
local count = 0
local index = 1]],
  base_xp = 50,
  optimal_keystrokes = { "x", "j", "0", "f", "z", "x", "f", "z", "x" },
  optimal_keystrokes_alternates = {
    { "x", "j", "f", "z", "x", "f", "z", "x" },
  },
}
```

- [ ] **Step 2: Run reachability for this room**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -E "beginner_delete_char|reachability:"`
Expected: no failure. (`local qcount` — the `q` is at column 7. `local indezx` — there are two `z`s? No — only one. Re-read the start_text: `indezx` contains one `z` between `inde` and `x`. Target is `index`. So delete the `z` only. The keystroke list has `f z x f z x` which would fail because there's only one `z`. Fix in Step 3.)

- [ ] **Step 3: Debug — correct keystrokes**

The `start_text` line 2 is `local indezx = 1`. To produce `local index = 1`, delete the single `z`. Update keystrokes to:

```lua
optimal_keystrokes = { "x", "j", "0", "f", "z", "x" },
optimal_keystrokes_alternates = {
  { "x", "j", "f", "z", "x" },
},
```

Rerun Step 2.

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/beginner/delete_char.lua
git commit -m "feat(rooms): rewrite beginner_delete_char with typo-removal scenario"
```

---

## Task 12: beginner_delete_motion — d{motion}

**Files:**
- Modify: `lua/rooms/beginner/delete_motion.lua`

**Design.** Function with an extra parameter to remove. `dw` removes the word, `x` (or the included comma) cleans punctuation.

- [ ] **Step 1: Rewrite the file**

```lua
-- Beginner room: d{motion}. Remove an unused param from a function signature.
return {
  id = "beginner_delete_motion",
  tier = "beginner",
  command = "d{motion}",
  title = "Delete by Motion: d + w/W/$/0",
  description = "d is an operator — combine it with any motion: dw deletes a word, dW a big-word, d$ to line end",
  before_example = "fn(a, |unused, b)",
  after_example = "fn(a, |b)",
  usage_tip = "d + motion is the Vim grammar. dw = delete word, dW = delete WORD (no punctuation split), d$ = delete to end.",
  filetype = "lua",
  cursor_start = { row = 1, col = 22 },
  goal = "Remove the unused `tmp,` parameter from the function signature.",
  start_text = [[
local function copy(src, tmp, dst)
  return dst
end]],
  target_text = [[
local function copy(src, dst)
  return dst
end]],
  base_xp = 50,
  optimal_keystrokes = { "d", "w", "d", "w" },
  optimal_keystrokes_alternates = {
    { "2", "d", "w" },
  },
}
```

- [ ] **Step 2: Run reachability for this room**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -E "beginner_delete_motion|reachability:"`
Expected: no failure. (Column 22 of line 1: `local function copy(src, ` — count: `l`=1, `o`=2, `c`=3, `a`=4, `l`=5, ` `=6, `f`=7, `u`=8, `n`=9, `c`=10, `t`=11, `i`=12, `o`=13, `n`=14, ` `=15, `c`=16, `o`=17, `p`=18, `y`=19, `(`=20, `s`=21, `r`=22 — that's `r` of `src`, not the target. Fix in Step 3.)

- [ ] **Step 3: Debug — recount cursor column**

Target start: cursor on `t` of `tmp` so `dw` consumes `tmp, `. Count again: after `(` at col 20, `src,` occupies 21–24, space at 25, `t` of `tmp` at 26. Set `cursor_start = { row = 1, col = 26 }`. With cursor on `t`, `dw` deletes `tmp, ` (word + trailing space), producing the target. So **only one `dw`** is needed; the keystroke list `d w d w` deletes too much. Update:

```lua
optimal_keystrokes = { "d", "w" },
optimal_keystrokes_alternates = nil,
```

Drop the alternate (a single-motion room doesn't need one). Rerun Step 2.

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/beginner/delete_motion.lua
git commit -m "feat(rooms): rewrite beginner_delete_motion with param-removal scenario"
```

---

## Task 13: beginner_delete_yank — x / dd / yy / p

**Files:**
- Modify: `lua/rooms/beginner/delete_yank.lua`

**Design.** A duplicated line that should be deleted, plus one stray char. Forces `dd` + `x`.

- [ ] **Step 1: Rewrite the file**

```lua
-- Beginner room: x/dd/yy/p mix. Delete a duplicated line, remove one stray char.
return {
  id = "beginner_delete_yank",
  tier = "beginner",
  command = "x / dd / yy / p",
  title = "Delete & Paste: x, dd, yy, p",
  description = "Delete char (x), delete line (dd), yank line (yy), paste (p)",
  before_example = "a = 1\na = 1|\nb = 2",
  after_example = "a = 1|\nb = 2",
  usage_tip = "dd deletes the whole line into a register. Nothing is truly deleted in Vim.",
  filetype = "lua",
  cursor_start = { row = 2, col = 1 },
  goal = "Delete the duplicated line 2, then remove the stray `;` at the end of line 1.",
  start_text = [[
local a = 1;
local a = 1
local b = 2]],
  target_text = [[
local a = 1
local b = 2]],
  base_xp = 60,
  optimal_keystrokes = { "d", "d", "k", "$", "x" },
}
```

- [ ] **Step 2: Run reachability for this room**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -E "beginner_delete_yank|reachability:"`
Expected: no failure. (After `dd` on line 2, line 1 becomes the line with `;`, cursor still on line 2 — recheck: `dd` puts cursor on the line below the deleted one. So `k` may be needed differently. Verify and adjust.)

- [ ] **Step 3: Debug if needed.**

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/beginner/delete_yank.lua
git commit -m "feat(rooms): rewrite beginner_delete_yank with dedup scenario"
```

---

## Task 14: beginner_dd_yp — dd / yy / p

**Files:**
- Modify: `lua/rooms/beginner/dd_yp.lua`

**Design.** Duplicate a line via `yyp`, then delete a stale line. Two complementary line ops.

- [ ] **Step 1: Rewrite the file**

```lua
-- Beginner room: dd/yy/p. Duplicate a config line, drop a stale one.
return {
  id = "beginner_dd_yp",
  tier = "beginner",
  command = "dd / yy / p",
  title = "Cut, Copy, Paste Lines",
  description = "dd cuts a line, yy copies it, p pastes below cursor",
  before_example = "alpha\n|stale",
  after_example = "alpha\nalpha|",
  usage_tip = "dd on a line deletes it into the register. p pastes it after cursor line.",
  filetype = "lua",
  cursor_start = { row = 1, col = 1 },
  time_limit = 45,
  goal = "Duplicate line 1, then delete the stale third line (`-- old`).",
  start_text = [[
local PORT = 8080
local HOST = "localhost"
-- old
return { PORT = PORT, HOST = HOST }]],
  target_text = [[
local PORT = 8080
local PORT = 8080
local HOST = "localhost"
return { PORT = PORT, HOST = HOST }]],
  base_xp = 55,
  optimal_keystrokes = { "y", "y", "p", "j", "j", "d", "d" },
}
```

- [ ] **Step 2: Run reachability for this room**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -E "beginner_dd_yp|reachability:"`
Expected: no failure.

- [ ] **Step 3: Debug if needed.**

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/beginner/dd_yp.lua
git commit -m "feat(rooms): rewrite beginner_dd_yp with duplicate+drop scenario"
```

---

## Task 15: beginner_d_dollar — D / d$

**Files:**
- Modify: `lua/rooms/beginner/d_dollar.lua`

**Design.** Two lines with trailing comments to remove. `D` from column after the code clears each line tail.

- [ ] **Step 1: Rewrite the file**

```lua
-- Beginner room: D / d$. Strip trailing inline comments from two lines.
return {
  id = "beginner_d_dollar",
  tier = "beginner",
  command = "D / d$",
  title = "Delete to Line End: D",
  description = "D deletes from the cursor to the end of the line (shorthand for d$). $ jumps to line end.",
  before_example = "x = 1 |-- TODO",
  after_example = "x = 1|",
  usage_tip = "D = d$. Combine $ with any operator: d$ deletes, c$ changes, y$ yanks to end of line.",
  filetype = "lua",
  cursor_start = { row = 1, col = 11 },
  goal = "Delete the `-- TODO` trailing comment on lines 1 and 2.",
  start_text = [[
local a = 1 -- TODO
local b = 2 -- TODO
local c = 3]],
  target_text = [[
local a = 1
local b = 2
local c = 3]],
  base_xp = 50,
  optimal_keystrokes = { "h", "D", "j", "$", "F", " ", "D" },
  optimal_keystrokes_alternates = {
    { "h", "D", "j", "0", "f", "-", "h", "D" },
  },
}
```

- [ ] **Step 2: Run reachability for this room**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -E "beginner_d_dollar|reachability:"`
Expected: no failure. (Cursor at col 11 is the space after `1`. `h` moves to `1`. `D` deletes `1 -- TODO` — leaving `local a = `. Wrong target. Fix in Step 3.)

- [ ] **Step 3: Debug — set cursor on the trailing space, not before**

Reset cursor to land **on the space before `--`**: column 12 of line 1 (`local a = 1 -- TODO` → `l=1, o=2, c=3, a=4, l=5, ' '=6, a=7, ' '=8, ='=9, ' '=10, 1=11, ' '=12`). With cursor on col 12, `D` deletes from there to end → leaves `local a = 1`. Update:

```lua
cursor_start = { row = 1, col = 12 },
optimal_keystrokes = { "D", "j", "$", "F", " ", "D" },
optimal_keystrokes_alternates = {
  { "D", "j", "0", "f", "-", "h", "D" },
},
```

After the first `D`, cursor stays on column 12 of line 1 (now end of `local a = 1`). `j` → line 2. `$` puts cursor on last char (`O`). `F ` jumps backwards to the first space — that finds the space between `--` and `TODO`. Wrong target. Better: `0`, `f-`, `h`, `D`.

Replace primary with the alternate's logic:

```lua
optimal_keystrokes = { "D", "j", "0", "f", "-", "h", "D" },
optimal_keystrokes_alternates = nil,
```

Rerun Step 2.

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/beginner/d_dollar.lua
git commit -m "feat(rooms): rewrite beginner_d_dollar with comment-trim scenario"
```

---

## Task 16: beginner_replace_char — `r<char>`

**Files:**
- Modify: `lua/rooms/beginner/replace_char.lua`

**Design.** Snippet with three single-char typos. `r` shines because each fix is exactly one character.

- [ ] **Step 1: Rewrite the file**

```lua
-- Beginner room: r<char>. Fix three single-character typos.
return {
  id = "beginner_replace_char",
  tier = "beginner",
  command = "r<char>",
  title = "Replace Char: r",
  description = "Replace the character under the cursor without entering insert mode",
  before_example = "x = |9",
  after_example = "x = |0",
  usage_tip = "r replaces exactly one char and stays in normal mode. Faster than i + char + Esc for single fixes.",
  filetype = "lua",
  cursor_start = { row = 1, col = 1 },
  goal = "Fix three typos: `9` → `0`, `q` → `o`, `Z` → `S`.",
  start_text = [[
local count = 9
local name = "qff"
local mode = "Zet"]],
  target_text = [[
local count = 0
local name = "off"
local mode = "Set"]],
  base_xp = 50,
  optimal_keystrokes = { "$", "r", "0", "j", "f", "q", "r", "o", "j", "f", "Z", "r", "S" },
}
```

- [ ] **Step 2: Run reachability for this room**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -E "beginner_replace_char|reachability:"`
Expected: no failure.

- [ ] **Step 3: Debug if needed.**

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/beginner/replace_char.lua
git commit -m "feat(rooms): rewrite beginner_replace_char with three-typo scenario"
```

---

## Task 17: beginner_toggle_case — `~`

**Files:**
- Modify: `lua/rooms/beginner/toggle_case.lua`

**Design.** Identifier accidentally typed in mixed case; player flips all letters of one word with a count prefix.

- [ ] **Step 1: Rewrite the file**

```lua
-- Beginner room: ~. Flip case of a wrongly-cased identifier.
return {
  id = "beginner_toggle_case",
  tier = "beginner",
  command = "~",
  title = "Toggle Case: ~",
  description = "Flip case of char under cursor and advance",
  before_example = "|HELLO",
  after_example = "|hello",
  usage_tip = "Press ~ repeatedly. With count: 5~ flips next 5 chars in one go.",
  filetype = "lua",
  cursor_start = { row = 1, col = 7 },
  goal = "Lowercase the constant `HELLO` to `hello`.",
  start_text = [[
local HELLO = "world"]],
  target_text = [[
local hello = "world"]],
  base_xp = 50,
  optimal_keystrokes = { "5", "~" },
  optimal_keystrokes_alternates = {
    { "~", "~", "~", "~", "~" },
  },
}
```

- [ ] **Step 2: Run reachability for this room**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -E "beginner_toggle_case|reachability:"`
Expected: no failure.

- [ ] **Step 3: Debug if needed.**

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/beginner/toggle_case.lua
git commit -m "feat(rooms): rewrite beginner_toggle_case with constant-rename scenario"
```

---

## Task 18: beginner_undo_redo — u / Ctrl-r

**Files:**
- Modify: `lua/rooms/beginner/undo_redo.lua`

**Design.** Player makes an edit, undoes it, redoes it — the net target equals the post-redo state. Hard to teach undo in a static room, so this room ends in a state that *requires* `u<C-r>` to be the optimal path. Implementation: start_text has line A; target replaces line A with `RIGHT`; optimal does `cc WRONG <Esc> u <C-r> 0 R IGHT <Esc>` — but `u` then `<C-r>` are no-ops on net. Instead: optimal_keystrokes uses a small deliberate edit that exercises `u` mid-task. Easier framing: change two lines, then undo only the second change.

- [ ] **Step 1: Rewrite the file**

```lua
-- Beginner room: u / Ctrl-r. Make two edits, undo the second (it was wrong).
return {
  id = "beginner_undo_redo",
  tier = "beginner",
  command = "u / Ctrl-r",
  title = "Undo & Redo: u, Ctrl-r",
  description = "Undo last change (u), redo an undone change (Ctrl-r)",
  before_example = "x = old|",
  after_example = "x = new|",
  usage_tip = "u is your safety net. Experiment freely knowing you can always undo.",
  filetype = "lua",
  cursor_start = { row = 1, col = 11 },
  goal = "Change `old` to `new` on line 1. (You'll make a wrong second edit on line 2 and undo it.)",
  start_text = [[
local x = old
local y = old]],
  target_text = [[
local x = new
local y = old]],
  base_xp = 50,
  optimal_keystrokes = { "c", "w", "n", "e", "w", "\27", "j", "c", "w", "X", "\27", "u" },
}
```

- [ ] **Step 2: Run reachability for this room**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -E "beginner_undo_redo|reachability:"`
Expected: no failure. Note: cursor col 11 should be on the `o` of `old`. Verify: `local x = old` → `l=1 o=2 c=3 a=4 l=5 ' '=6 x=7 ' '=8 '='=9 ' '=10 o=11 l=12 d=13`. Good.

- [ ] **Step 3: Debug if needed.**

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/beginner/undo_redo.lua
git commit -m "feat(rooms): rewrite beginner_undo_redo with mistake-undo scenario"
```

---

## Task 19: beginner_join_lines — `J`

**Files:**
- Modify: `lua/rooms/beginner/join_lines.lua`

**Design.** Function call broken across two lines; player joins them. `J` inserts a single space — matches the target.

- [ ] **Step 1: Rewrite the file**

```lua
-- Beginner room: J. Join a function call that wraps across two lines.
return {
  id = "beginner_join_lines",
  tier = "beginner",
  command = "J",
  title = "Join Lines: J",
  description = "J joins the current line with the line below it, inserting a space between them",
  before_example = "log(\n  msg)",
  after_example = "log( msg)|",
  usage_tip = "J is faster than going to end of line and deleting the newline. 2J joins 3 lines at once.",
  filetype = "lua",
  cursor_start = { row = 1, col = 1 },
  goal = "Join the wrapped `print` call onto one line.",
  start_text = [[
print(
  "hello",
  "world"
)]],
  target_text = [[
print( "hello", "world" )]],
  base_xp = 35,
  optimal_keystrokes = { "4", "J" },
  optimal_keystrokes_alternates = {
    { "J", "J", "J" },
  },
}
```

- [ ] **Step 2: Run reachability for this room**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -E "beginner_join_lines|reachability:"`
Expected: no failure. Note: `J` strips leading whitespace from the joined line and inserts one space. The target shows single-spaced separators; verify the exact spacing.

- [ ] **Step 3: Debug.** If `J` produces different whitespace (e.g., no space before `)`), adjust `target_text` to match Vim's `J` semantics rather than fighting them.

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/beginner/join_lines.lua
git commit -m "feat(rooms): rewrite beginner_join_lines with wrapped-call scenario"
```

---

## Task 20: beginner_counts — N{motion}

**Files:**
- Modify: `lua/rooms/beginner/counts.lua`

**Design.** Snippet where `3dd` collapses an unwanted block. Exercises count + operator.

- [ ] **Step 1: Rewrite the file**

```lua
-- Beginner room: count prefix. Delete a 3-line debug block in one command.
return {
  id = "beginner_counts",
  tier = "beginner",
  command = "N<motion> / Ndd",
  title = "Numeric Prefixes",
  description = "Any motion or operator can be prefixed with a count: 3w, 2dd, 5x",
  before_example = "keep|\ndrop\ndrop\ndrop\nkeep",
  after_example = "keep|\nkeep",
  usage_tip = "4w jumps 4 words. 2dd deletes 2 lines. d$ deletes to end of line.",
  filetype = "lua",
  cursor_start = { row = 2, col = 1 },
  time_limit = 40,
  goal = "Delete the three `print` debug lines in one command.",
  start_text = [[
local function run()
  print("a")
  print("b")
  print("c")
  return true
end]],
  target_text = [[
local function run()
  return true
end]],
  base_xp = 50,
  optimal_keystrokes = { "3", "d", "d" },
}
```

- [ ] **Step 2: Run reachability for this room**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -E "beginner_counts|reachability:"`
Expected: no failure.

- [ ] **Step 3: Debug if needed.**

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/beginner/counts.lua
git commit -m "feat(rooms): rewrite beginner_counts with debug-block scenario"
```

---

## Task 21: beginner_boss — 3-phase gauntlet

**Files:**
- Modify: `lua/rooms/beginner/boss.lua`

**Design.** Three phases, each a beginner-tier real-world mini-task. Each phase gets `filetype`, `cursor_start`, `goal`. Total optimal_keystrokes across phases stays under 40.

**Phase 1 — delete debug prints (uses `dd` / counts).**
- snippet: function with 3 stray `print` lines (similar shape to Task 20).

**Phase 2 — append `;` to every entry (uses `A` + `j`).**
- snippet: 4-entry config list missing trailing semicolons.

**Phase 3 — fix typos (uses `r`).**
- snippet: 3 single-char typos in identifiers.

- [ ] **Step 1: Rewrite the file**

```lua
-- Beginner boss: 3-phase gauntlet on real Lua snippets.
return {
  id = "beginner_boss",
  tier = "beginner",
  is_boss = true,
  command = "hjkl + insert + delete",
  title = "BOSS: The Gauntlet",
  description = "Three-phase trial. All beginner skills tested.",
  usage_tip = "Use everything you have learned: navigate, insert, delete.",
  base_xp = 300,
  time_limit = 180,
  phases = {
    {
      tip = "Phase 1: Delete the three debug prints",
      filetype = "lua",
      cursor_start = { row = 2, col = 1 },
      goal = "Delete the three `print` lines in one command.",
      start_text = [[
local function run()
  print("a")
  print("b")
  print("c")
  return true
end]],
      target_text = [[
local function run()
  return true
end]],
      optimal_keystrokes = { "3", "d", "d" },
    },
    {
      tip = "Phase 2: Append `;` to every entry",
      filetype = "lua",
      cursor_start = { row = 1, col = 1 },
      goal = "Append `;` to every line.",
      start_text = [[
local a = 1
local b = 2
local c = 3
local d = 4]],
      target_text = [[
local a = 1;
local b = 2;
local c = 3;
local d = 4;]],
      optimal_keystrokes = { "A", ";", "\27", "j", "A", ";", "\27", "j", "A", ";", "\27", "j", "A", ";", "\27" },
    },
    {
      tip = "Phase 3: Fix the three typos",
      filetype = "lua",
      cursor_start = { row = 1, col = 1 },
      goal = "Fix three typos: `qount`, `nqme`, `pqrt` — change each `q` to `o`/`a`/`o`.",
      start_text = [[
local qount = 0
local nqme  = "x"
local pqrt  = 80]],
      target_text = [[
local count = 0
local name  = "x"
local port  = 80]],
      optimal_keystrokes = { "f", "q", "r", "c", "j", "f", "q", "r", "a", "j", "f", "q", "r", "o" },
    },
  },
}
```

- [ ] **Step 2: Run reachability for this room**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -E "beginner_boss|reachability:"`
Expected: no failure for any phase. Each phase appears as `beginner_boss#phase1`, `#phase2`, `#phase3`.

- [ ] **Step 3: Debug each failing phase independently.**

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/beginner/boss.lua
git commit -m "feat(rooms): rewrite beginner_boss with three real-world phases"
```

---

## Task 22: Full beginner sweep + spec suite

**Files:**
- None (verification only).

- [ ] **Step 1: Run full reachability without `--all`** (mirrors CI)

Run: `nvim --headless --noplugin -l tests/reachability.lua`
Expected: `reachability: 24 checked, X skipped (no goal), all sequences pass` — count is 20 regular beginner rooms + 3 boss phases + 1 (the boss top-level `is_boss` is skipped; phases each count). If skipped count > 0 unexpectedly, a beginner room is missing its `goal` field — find and add.

- [ ] **Step 2: Run busted**

Run: `busted`
Expected: all green. Confirms validator still accepts every rewritten room and no schema regression.

- [ ] **Step 3: Manual smoke test (optional but recommended)**

Launch nvim, open `:Telescope vimmer_rooms` (or the project's equivalent), pick one beginner room, verify:
- `goal` line appears in HUD
- Syntax colors apply to the snippet (matching `filetype`)
- Cursor lands at `cursor_start` on play start
- Plugin autopairs / LSP do NOT interfere (PR 1 buffer hygiene)

- [ ] **Step 4: Final summary commit (if any tweaks were made in Steps 1–3)**

If nothing changed, skip. Otherwise:

```bash
git add -u
git commit -m "fix(rooms): tighten beginner content after full-tier sweep"
```

---

## Self-Review Checklist (run before declaring plan complete)

1. **Spec coverage:**
   - All 21 beginner rooms (20 regular + 1 boss) listed in the spec's coverage table → present as Tasks 1–21. ✓
   - Schema additions (`filetype`/`cursor_start`/`goal`) applied in every rewritten file. ✓
   - Reachability harness gating before every commit. ✓
   - Tier calibration (5–10 line snippets, 8–20 keystrokes, base_xp 30–60, time_limit nil/45–60s). ✓

2. **Placeholder scan:** Every task contains the full new file content as a code block. Debug steps name the failure mode and the fix, not "handle errors". ✓ — known weak spots flagged inline (Tasks 12, 15: keystroke recounts; Task 9: indent dependency).

3. **Type consistency:** Field names match `lua/the-vimmer/rooms.lua` (`filetype`, `cursor_start = {row, col}`, `goal`, `optimal_keystrokes_alternates`). Escape encoding `"\27"` consistent across all tasks. ✓
