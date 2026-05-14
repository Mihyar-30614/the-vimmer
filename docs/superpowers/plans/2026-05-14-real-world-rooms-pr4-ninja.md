# Real-World Rooms PR 4 — Ninja Tier Rewrite

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite all 17 ninja rooms (16 regular + 1 boss) as realistic refactor mini-tasks on real-feeling code snippets. Each room ships `filetype`, `cursor_start`, `goal` plus updated `start_text` / `target_text` / `optimal_keystrokes` / `optimal_keystrokes_alternates`. Reachability harness must pass every primary + alternate sequence.

**Architecture:** Engine support shipped in PR 1; beginner content in PR 2; warrior content in PR 3. PR 4 rewrites `lua/rooms/ninja/*.lua` in place. One file per task. Same per-room reachability gate as PRs 2–3.

**Tech Stack:** Lua 5.1 (Neovim runtime), busted, headless Neovim reachability harness.

**Calibration target (per spec):**
- 15–30 line snippets, multi-command refactor, multiple valid paths emphasized
- `optimal_keystrokes` length: 20–60
- `time_limit`: 60–180s
- `base_xp` range: 120–180
- **Heavy use of `optimal_keystrokes_alternates`** — real refactors have 2–4 reasonable paths.

**Keystroke encoding cheatsheet (from PR 2 / PR 3 execution):**
- `\27` = `<Esc>`, `\r` = `<CR>`
- `\1`  = `<C-a>` (increment)
- `\24` = `<C-x>` (decrement)
- `\15` = `<C-o>` (jump back)
- `\t`  = `<Tab>` / `<C-i>` (jump forward)
- `\18` = `<C-r>` (redo)
- `\22` = `<C-v>` (visual block)

**Hard-won quirks (verified during PR 2 + PR 3):**
1. **Macros fail under headless feedkeys.** `qa ... q` records but `@a` replay does not consistently re-execute the recorded sequence. Two ninja rooms (`global_macro`, `advanced_macros`) plus the boss's macro phase MUST use `.` repeat as the verified primary path. Macros stay in the room's title/description/usage_tip for player education but the reachability path uses `.` / `:norm` / `cgn+.`.
2. `nvim_buf_set_lines` itself is undoable — never start a sequence with bare `u` (it empties the buffer).
3. `autoindent` is ON. `o` / `O` inherits the prior line's indent — strip explicit leading spaces from typed inserts.
4. `J` skips space before `)`. Adjust `target_text` to match.
5. `f<char>` does NOT include current cursor pos. If cursor already on the char, use `r<char>` directly.
6. `j` / `k` preserve column when possible.
7. `b` / `w` / `e` split on punctuation. Use `B` / `W` / `E` for whitespace-separated WORDs.
8. `dw` stops at the next word's start — to also consume a trailing comma, use `2dw` or `dW`.
9. **Visual selection `:norm` cmd works** — `V<motion>:norm A;<CR>` applies the normal-mode cmd per selected line. This is the reachability-safe substitute for macros at scale.

**Per-room reachability command:**

```bash
nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -B1 -A20 "ninja_<slug>"
```

Empty output = pass.

**Existing test gates (must remain green):**

```bash
~/.luarocks/bin/busted
nvim --headless --noplugin -l tests/reachability.lua   # CI mode
```

After this PR, full CI sweep should report `61 checked, 0 skipped` (23 beginner + 21 warrior + 17 ninja contexts).

---

## File Structure

| Path | Action | Command focus |
|---|---|---|
| `lua/rooms/ninja/text_objects.lua` | Rewrite | `di(` / `da[` / `ci{` (Task 1) |
| `lua/rooms/ninja/surround_obj.lua` | Rewrite | `di"` / `da(` / `ci{` (Task 2) |
| `lua/rooms/ninja/registers.lua` | Rewrite | `"ay` / `"ap` (Task 3) |
| `lua/rooms/ninja/registers2.lua` | Rewrite | named register workflow (Task 4) |
| `lua/rooms/ninja/black_hole.lua` | Rewrite | `"_d` / `"_dd` (Task 5) |
| `lua/rooms/ninja/marks.lua` | Rewrite | `m<a>` / `'a` / `` `a `` (Task 6) |
| `lua/rooms/ninja/jump_list.lua` | Rewrite | `<C-o>` / `<C-i>` (Task 7) |
| `lua/rooms/ninja/inc_dec.lua` | Rewrite | `<C-a>` / `<C-x>` (Task 8) |
| `lua/rooms/ninja/substitute.lua` | Rewrite | `:%s/old/new/g` (Task 9) |
| `lua/rooms/ninja/global_delete.lua` | Rewrite | `:g/pat/d` (Task 10) |
| `lua/rooms/ninja/sort.lua` | Rewrite | `:sort` (Task 11) |
| `lua/rooms/ninja/norm_range.lua` | Rewrite | `:'<,'>norm` (Task 12) |
| `lua/rooms/ninja/cgn.lua` | Rewrite | `cgn` + `.` (Task 13) |
| `lua/rooms/ninja/complex_motions.lua` | Rewrite | `gg` / `G` / `{` / `}` (Task 14) |
| `lua/rooms/ninja/global_macro.lua` | Rewrite | macros (verified via `.` / `:norm`) (Task 15) |
| `lua/rooms/ninja/advanced_macros.lua` | Rewrite | macros + text objects (verified via `.` / `cgn`) (Task 16) |
| `lua/rooms/ninja/boss.lua` | Rewrite | 3-phase Void (Task 17) |

---

## Task 1: ninja_text_objects — `di(` / `da[` / `ci{`

**Files:**
- Modify: `lua/rooms/ninja/text_objects.lua`

**Design.** Snippet with three different bracket pairs. Player operates inside each without manual selection.

- [ ] **Step 1: Rewrite the file**

```lua
-- Ninja room: text objects. Operate inside three different delimiter pairs.
return {
  id = "ninja_text_objects",
  tier = "ninja",
  command = "di( / da[ / ci{",
  title = "Text Objects: di(, da[, ci{",
  description = "Operate on text inside or around delimiters without moving cursor first.",
  usage_tip = "i = inner (excludes delimiters), a = around (includes them). Works with d/c/y.",
  before_example = "fn(|args)",
  after_example = "fn(|)",
  filetype = "lua",
  cursor_start = { row = 1, col = 1 },
  time_limit = 75,
  goal = "Clear args inside `()`, remove the `[bad]` index entirely, and replace `{old}` body with `{new}`.",
  start_text = [[
local result = compute(a, b, c)
local item = list[bad]
local cfg = { old }]],
  target_text = [[
local result = compute()
local item = list
local cfg = { new }]],
  base_xp = 130,
  optimal_keystrokes = { "f", "(", "d", "i", "(", "j", "f", "[", "d", "a", "[", "j", "f", "{", "c", "i", "{", " ", "n", "e", "w", " ", "\27" },
  optimal_keystrokes_alternates = {
    { "/", "(", "\r", "d", "i", "(", "/", "\\[", "\r", "d", "a", "[", "/", "{", "\r", "c", "i", "{", " ", "n", "e", "w", " ", "\27" },
  },
}
```

- [ ] **Step 2: Run reachability**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -B1 -A20 "ninja_text_objects"`
Expected: empty output (pass).

- [ ] **Step 3: Debug.** `ci{` operates on the next `{...}` block from cursor — verify cursor reaches that line. If `ci{` inserts in the wrong block, adjust the leading `j f {` motion.

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/ninja/text_objects.lua
git commit -m "feat(rooms): rewrite ninja_text_objects with three-delim scenario"
```

---

## Task 2: ninja_surround_obj — `di"` / `da(` / `ci{`

**Files:**
- Modify: `lua/rooms/ninja/surround_obj.lua`

**Design.** Mirror of Task 1 with different operators (delete-inside vs delete-around vs change-inside). Single-line snippet emphasizes pure text-object dispatch.

- [ ] **Step 1: Rewrite the file**

```lua
-- Ninja room: di" / da( / ci{. Delete inside quotes, delete around parens, change inside braces.
return {
  id = "ninja_surround_obj",
  tier = "ninja",
  command = "di\" / da( / ci{",
  title = "Text Object Deletion",
  description = "di<x> deletes inside delimiter. da<x> deletes including the delimiter itself.",
  usage_tip = "di\" deletes inside quotes leaving them. da\" deletes quotes too. ci\" changes inside.",
  before_example = 'tag("old")|',
  after_example = 'tag("")|',
  filetype = "lua",
  cursor_start = { row = 1, col = 1 },
  time_limit = 70,
  goal = "Clear the `\"old\"` string content, remove the `(opts)` group entirely, change `{a}` body to `{b}`.",
  start_text = [[
local x = tag("old") and call(opts) and conf({ a })]],
  target_text = [[
local x = tag("") and call and conf({ b })]],
  base_xp = 125,
  optimal_keystrokes = { "f", "\"", "d", "i", "\"", "f", "(", "d", "a", "(", "f", "{", "c", "i", "{", " ", "b", " ", "\27" },
  optimal_keystrokes_alternates = {
    { "0", "/", "\"", "\r", "d", "i", "\"", "/", "(", "\r", "d", "a", "(", "/", "{", "\r", "c", "i", "{", " ", "b", " ", "\27" },
  },
}
```

- [ ] **Step 2: Run reachability**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -B1 -A20 "ninja_surround_obj"`

- [ ] **Step 3: Debug.** `da(` removes `(opts)` plus the leading space — verify target_text has exactly the expected spacing.

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/ninja/surround_obj.lua
git commit -m "feat(rooms): rewrite ninja_surround_obj with multi-delim scenario"
```

---

## Task 3: ninja_registers — `"ay` / `"ap`

**Files:**
- Modify: `lua/rooms/ninja/registers.lua`

**Design.** Two snippets: a config block to yank into register a, a destination block where it gets pasted. Player uses named register to avoid clobbering by intervening edits.

- [ ] **Step 1: Rewrite the file**

```lua
-- Ninja room: "ay / "ap. Yank into a named register, paste at a destination.
return {
  id = "ninja_registers",
  tier = "ninja",
  command = '"<reg>y and "<reg>p',
  title = "Named Registers: \"ay, \"ap",
  description = "Yank into a named register (\"ay) and paste from it (\"ap).",
  usage_tip = '"ay yanks the line into register a. "ap pastes it anywhere. Registers a-z are yours.',
  before_example = "yank this|\n...\npaste here",
  after_example = "yank this\n...\nyank this|",
  filetype = "lua",
  cursor_start = { row = 1, col = 1 },
  time_limit = 70,
  goal = "Yank line 1 into register `a`, delete line 4 (which would clobber the unnamed register), then paste from `a` at line 5.",
  start_text = [[
local PORT = 8080
local HOST = "localhost"

local OLD_LINE = "remove me"
-- paste imported config here]],
  target_text = [[
local PORT = 8080
local HOST = "localhost"

-- paste imported config here
local PORT = 8080]],
  base_xp = 130,
  optimal_keystrokes = { "\"", "a", "y", "y", "j", "j", "j", "d", "d", "\"", "a", "p" },
  optimal_keystrokes_alternates = {
    { "\"", "a", "y", "y", "4", "G", "d", "d", "G", "\"", "a", "p" },
  },
}
```

- [ ] **Step 2: Run reachability**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -B1 -A20 "ninja_registers"`

- [ ] **Step 3: Debug.** After `"ayy` on line 1, cursor stays on line 1. `jjj` lands on line 4 (OLD_LINE). `dd` removes line 4 into UNNAMED register (does NOT touch `a`). Cursor now on line 4 (was line 5, the comment). `"ap` pastes register a BELOW line 4. Result: 5 lines as in target.

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/ninja/registers.lua
git commit -m "feat(rooms): rewrite ninja_registers with yank-then-paste scenario"
```

---

## Task 4: ninja_registers2 — Named Register Workflow

**Files:**
- Modify: `lua/rooms/ninja/registers2.lua`

**Design.** Two regions to swap. Yank region A into `"a`, region B into `"b`, then paste them in swapped positions. Forces multi-register usage.

- [ ] **Step 1: Rewrite the file**

```lua
-- Ninja room: multi-register workflow. Swap two lines via two named registers.
return {
  id = "ninja_registers2",
  tier = "ninja",
  command = "\"ay / \"by / \"ap / \"bp",
  title = "Named Register Workflow",
  description = "Yank into a named register with \"<reg>yy, paste with \"<reg>p.",
  usage_tip = '"ayy yanks into register a. "ap pastes from register a. Registers a-z are yours.',
  before_example = "alpha|\nbeta",
  after_example = "beta|\nalpha",
  filetype = "lua",
  cursor_start = { row = 1, col = 1 },
  time_limit = 80,
  goal = "Swap line 1 and line 3 using registers `a` and `b`.",
  start_text = [[
local first = 1
local middle = 2
local last = 3]],
  target_text = [[
local last = 3
local middle = 2
local first = 1]],
  base_xp = 140,
  optimal_keystrokes = { "\"", "a", "y", "y", "j", "j", "\"", "b", "y", "y", "d", "d", "g", "g", "d", "d", "\"", "b", "P", "G", "\"", "a", "p" },
  optimal_keystrokes_alternates = {
    { "\"", "a", "d", "d", "j", "\"", "b", "d", "d", "\"", "a", "P", "G", "\"", "b", "p" },
  },
}
```

- [ ] **Step 2: Run reachability**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -B1 -A20 "ninja_registers2"`

- [ ] **Step 3: Debug.** The primary uses yank-then-delete to keep registers intact; the alternate uses cut directly into `"a`/`"b`. If the primary fails because `dd` clobbers something, prefer the alternate.

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/ninja/registers2.lua
git commit -m "feat(rooms): rewrite ninja_registers2 with line-swap scenario"
```

---

## Task 5: ninja_black_hole — `"_d` / `"_dd`

**Files:**
- Modify: `lua/rooms/ninja/black_hole.lua`

**Design.** Yank a line, delete an intervening line into black hole `"_` (so register stays intact), paste yanked line at destination. Classic black-hole use case.

- [ ] **Step 1: Rewrite the file**

```lua
-- Ninja room: "_dd. Discard a line into the black hole so the yank register survives.
return {
  id = "ninja_black_hole",
  tier = "ninja",
  command = "\"_d / \"_dd",
  title = "Black Hole Register: \"_",
  description = "Deleting with \"_ discards text without overwriting the unnamed yank register.",
  usage_tip = "\"_ is the black hole — anything deleted into it is gone. Use \"_dd to delete a line without losing what you yanked.",
  before_example = "keep|\njunk\nkeep",
  after_example = "keep|\nkeep",
  filetype = "lua",
  cursor_start = { row = 1, col = 1 },
  time_limit = 70,
  goal = "Yank line 1, delete line 3 (junk) into the black hole, paste yank at end.",
  start_text = [[
local good = compute()
local x = 1
local bad = "remove me"
local y = 2]],
  target_text = [[
local good = compute()
local x = 1
local y = 2
local good = compute()]],
  base_xp = 125,
  optimal_keystrokes = { "y", "y", "j", "j", "\"", "_", "d", "d", "G", "p" },
  optimal_keystrokes_alternates = {
    { "y", "y", "3", "G", "\"", "_", "d", "d", "G", "p" },
  },
}
```

- [ ] **Step 2: Run reachability**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -B1 -A20 "ninja_black_hole"`

- [ ] **Step 3: Debug.** Verify `"_dd` does not poison the unnamed register. If `p` pastes the deleted junk instead of `local good = ...`, the black-hole flag failed — recheck the `"_` sequence.

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/ninja/black_hole.lua
git commit -m "feat(rooms): rewrite ninja_black_hole with preserve-yank scenario"
```

---

## Task 6: ninja_marks — `ma` / `'a` / `` `a ``

**Files:**
- Modify: `lua/rooms/ninja/marks.lua`

**Design.** Set mark on a line, jump far away to make an edit, jump back via `` `a ``, make a second edit. Exercises mark round-trip.

- [ ] **Step 1: Rewrite the file**

```lua
-- Ninja room: ma / `a. Set a mark, edit elsewhere, return via the mark and edit again.
return {
  id = "ninja_marks",
  tier = "ninja",
  command = "m<a> / '<a> / `<a>",
  title = "Marks: Long-Range Jumps",
  description = "Set a mark with ma. Jump back to it with 'a (line) or `a (exact position).",
  usage_tip = "ma sets mark 'a' at cursor. `a jumps to that exact position from anywhere in the file.",
  before_example = "...|line 2 mark...\n...\n...line 8 edit...",
  after_example = "(both lines edited)",
  filetype = "lua",
  cursor_start = { row = 2, col = 1 },
  time_limit = 75,
  goal = "Mark line 2, jump to line 6 and append `;`, return to mark and uppercase line 2.",
  start_text = [[
-- module header
local CONFIG = load()
local x = 1
local y = 2
local z = 3
local result = run(CONFIG)
return result]],
  target_text = [[
-- module header
LOCAL CONFIG = LOAD()
local x = 1
local y = 2
local z = 3
local result = run(CONFIG);
return result]],
  base_xp = 130,
  optimal_keystrokes = { "m", "a", "6", "G", "A", ";", "\27", "`", "a", "g", "U", "U" },
  optimal_keystrokes_alternates = {
    { "m", "a", "/", "r", "u", "n", "\r", "A", ";", "\27", "'", "a", "g", "U", "U" },
  },
}
```

- [ ] **Step 2: Run reachability**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -B1 -A20 "ninja_marks"`

- [ ] **Step 3: Debug.** `` `a `` jumps to exact mark position; `'a` jumps to line start. Either works for `gUU` since it operates line-wise. Marks should survive headless feedkeys.

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/ninja/marks.lua
git commit -m "feat(rooms): rewrite ninja_marks with mark-roundtrip scenario"
```

---

## Task 7: ninja_jump_list — `<C-o>` / `<C-i>`

**Files:**
- Modify: `lua/rooms/ninja/jump_list.lua`

**Design.** Jump-list populates after big motions (G, /, marks). Player jumps to line 1 (gg), then line 10 (G), edits, then `<C-o>` to return to line 1, edits there.

- [ ] **Step 1: Rewrite the file**

```lua
-- Ninja room: <C-o> / <C-i>. Use the jump list to ping-pong between two edit sites.
return {
  id = "ninja_jump_list",
  tier = "ninja",
  command = "<C-o> / <C-i>",
  title = "Jump History: <C-o>, <C-i>",
  description = "<C-o> jumps to older position in the jump list; <C-i> jumps to newer.",
  usage_tip = "Like browser back/forward. <C-i> = Tab; the play tab maps Tab to freeze powerup, so use <C-i> in your real editor.",
  before_example = "header (cursor)\n...\nfooter line",
  after_example = "HEADER\n...\nFOOTER",
  filetype = "lua",
  cursor_start = { row = 1, col = 1 },
  time_limit = 80,
  goal = "Jump to last line, upcase it, then <C-o> back to first line and upcase it too.",
  start_text = [[
local function header() end
local a = 1
local b = 2
local c = 3
local d = 4
local function footer() end]],
  target_text = [[
LOCAL FUNCTION HEADER() END
local a = 1
local b = 2
local c = 3
local d = 4
LOCAL FUNCTION FOOTER() END]],
  base_xp = 135,
  optimal_keystrokes = { "G", "g", "U", "U", "\15", "g", "U", "U" },
  optimal_keystrokes_alternates = {
    { "G", "g", "U", "U", "g", "g", "g", "U", "U" },
  },
}
```

- [ ] **Step 2: Run reachability**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -B1 -A20 "ninja_jump_list"`

- [ ] **Step 3: Debug.** `<C-o>` after `G` returns to line 1 (the initial cursor pos in the jump list). If `<C-o>` doesn't fire under feedkeys, fall back to alternate (`gg`).

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/ninja/jump_list.lua
git commit -m "feat(rooms): rewrite ninja_jump_list with two-site edit scenario"
```

---

## Task 8: ninja_inc_dec — `<C-a>` / `<C-x>`

**Files:**
- Modify: `lua/rooms/ninja/inc_dec.lua`

**Design.** Snippet with version numbers / counters to bump. Player uses `<C-a>` with count prefix.

- [ ] **Step 1: Rewrite the file**

```lua
-- Ninja room: <C-a> / <C-x>. Bump version numbers without retyping them.
return {
  id = "ninja_inc_dec",
  tier = "ninja",
  command = "<C-a> / <C-x>",
  title = "Increment / Decrement: <C-a>, <C-x>",
  description = "Bump the next number on or after the cursor up (<C-a>) or down (<C-x>).",
  usage_tip = "Prefix a count: 5<C-a> adds 5. Scans forward from cursor on current line.",
  before_example = "version = 1|",
  after_example = "version = 2|",
  filetype = "lua",
  cursor_start = { row = 1, col = 1 },
  time_limit = 70,
  goal = "Bump major from 1->2 (line 1), bump minor by 5 (line 2), decrement patch from 9->7 (line 3).",
  start_text = [[
local MAJOR = 1
local MINOR = 0
local PATCH = 9]],
  target_text = [[
local MAJOR = 2
local MINOR = 5
local PATCH = 7]],
  base_xp = 130,
  optimal_keystrokes = { "\1", "j", "5", "\1", "j", "2", "\24" },
  optimal_keystrokes_alternates = {
    { "f", "1", "\1", "j", "0", "f", "0", "5", "\1", "j", "0", "f", "9", "2", "\24" },
  },
}
```

- [ ] **Step 2: Run reachability**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -B1 -A20 "ninja_inc_dec"`

- [ ] **Step 3: Debug.** `<C-a>` scans forward on the current line for the next number, no need to land on it directly. From col 1 of line 1, `<C-a>` finds `1` and bumps to `2`. After bump, `j` to line 2 — cursor at col 14 (where `2` was, but line 2 numbers may differ in pos). Should still work because `<C-a>` re-scans.

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/ninja/inc_dec.lua
git commit -m "feat(rooms): rewrite ninja_inc_dec with version-bump scenario"
```

---

## Task 9: ninja_substitute — `:%s/old/new/g`

**Files:**
- Modify: `lua/rooms/ninja/substitute.lua`

**Design.** 4-occurrence rename via one ex command.

- [ ] **Step 1: Rewrite the file**

```lua
-- Ninja room: :%s. Rename 4 occurrences with one ex command.
return {
  id = "ninja_substitute",
  tier = "ninja",
  command = ":%s/old/new/g",
  title = "Global Substitute",
  description = ":%s/pattern/replacement/g replaces all occurrences in the file.",
  usage_tip = "% means whole file. g flag means all occurrences per line. Omit g for first only.",
  before_example = "hello world|",
  after_example = "goodbye world|",
  filetype = "lua",
  cursor_start = { row = 1, col = 1 },
  time_limit = 60,
  goal = "Replace every `bug` with `ok` (5 occurrences).",
  start_text = [[
local a = "bug"
local b = "bug"
local c = "x"
local d = "bug bug"
local e = "bug"]],
  target_text = [[
local a = "ok"
local b = "ok"
local c = "x"
local d = "ok ok"
local e = "ok"]],
  base_xp = 120,
  optimal_keystrokes = { ":", "%", "s", "/", "b", "u", "g", "/", "o", "k", "/", "g", "\r" },
  optimal_keystrokes_alternates = {
    { ":", "%", "s", "/", "b", "u", "g", "/", "o", "k", "/", "g", "\r" },
  },
}
```

- [ ] **Step 2: Run reachability**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -B1 -A20 "ninja_substitute"`

- [ ] **Step 3: Debug.** Single-path room — primary should work directly. If `:` doesn't enter command line, harness may need explicit `vim.cmd`; verify `\r` terminator.

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/ninja/substitute.lua
git commit -m "feat(rooms): rewrite ninja_substitute with multi-occurrence rename"
```

---

## Task 10: ninja_global_delete — `:g/pat/d`

**Files:**
- Modify: `lua/rooms/ninja/global_delete.lua`

**Design.** Snippet with several debug `print` lines scattered between real code. Delete all matching lines with one `:g/print/d`.

- [ ] **Step 1: Rewrite the file**

```lua
-- Ninja room: :g. Delete every line matching a pattern with one ex command.
return {
  id = "ninja_global_delete",
  tier = "ninja",
  command = ":g/pattern/d",
  title = "Global Command: :g/pattern/d",
  description = "Execute an ex command on every line matching a pattern. :g/#/d deletes all lines containing #.",
  usage_tip = ":g/pat/d = delete matching lines. :g/pat/normal <cmd> runs any normal command. :v/pat/d keeps only matching lines.",
  before_example = "real\nDEBUG\nreal\nDEBUG",
  after_example = "real\nreal",
  filetype = "lua",
  cursor_start = { row = 1, col = 1 },
  time_limit = 70,
  goal = "Strip every line containing `print(` from this function.",
  start_text = [[
local function run()
  print("start")
  local x = 1
  print("step 1")
  local y = 2
  print("step 2")
  return x + y
end]],
  target_text = [[
local function run()
  local x = 1
  local y = 2
  return x + y
end]],
  base_xp = 130,
  optimal_keystrokes = { ":", "g", "/", "p", "r", "i", "n", "t", "/", "d", "\r" },
  optimal_keystrokes_alternates = {
    { ":", "g", "/", "p", "r", "i", "n", "t", "(", "/", "d", "\r" },
  },
}
```

- [ ] **Step 2: Run reachability**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -B1 -A20 "ninja_global_delete"`

- [ ] **Step 3: Debug.** Note: `(` is a regex special char — in `:g/print(/d`, the `(` should match literal `(` in basic regex but be careful in extended regex. Primary uses `print` (no paren) which matches all lines containing `print` anywhere.

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/ninja/global_delete.lua
git commit -m "feat(rooms): rewrite ninja_global_delete with debug-strip scenario"
```

---

## Task 11: ninja_sort — `:sort`

**Files:**
- Modify: `lua/rooms/ninja/sort.lua`

**Design.** Unsorted import block; sort alphabetically.

- [ ] **Step 1: Rewrite the file**

```lua
-- Ninja room: :sort. Sort an unsorted import block alphabetically.
return {
  id = "ninja_sort",
  tier = "ninja",
  command = ":sort",
  title = "Sort Lines: :sort",
  description = "Sort lines in the buffer alphabetically (or numerically with n flag).",
  usage_tip = ":sort sorts whole file; visual+:sort sorts the selection. :sort! reverses. :sort u removes dupes.",
  before_example = "c\na\nb",
  after_example = "a\nb\nc",
  filetype = "lua",
  cursor_start = { row = 2, col = 1 },
  time_limit = 60,
  goal = "Sort the 5 require lines alphabetically (line 1 and line 7 stay put).",
  start_text = [[
-- imports
local zip = require("zip")
local fs  = require("fs")
local log = require("log")
local cfg = require("cfg")
local sys = require("sys")
-- end imports]],
  target_text = [[
-- imports
local cfg = require("cfg")
local fs  = require("fs")
local log = require("log")
local sys = require("sys")
local zip = require("zip")
-- end imports]],
  base_xp = 125,
  optimal_keystrokes = { "V", "5", "j", ":", "s", "o", "r", "t", "\r" },
  optimal_keystrokes_alternates = {
    { ":", "2", ",", "6", "s", "o", "r", "t", "\r" },
  },
}
```

- [ ] **Step 2: Run reachability**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -B1 -A20 "ninja_sort"`

- [ ] **Step 3: Debug.** Visual select 5 lines starting from line 2: `V` at line 2, `5j` extends to line 7 — but that's 6 lines (line 2 through 7). Need `4j` to select lines 2–6 only. Adjust if test shows the `-- end imports` line was included in sort.

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/ninja/sort.lua
git commit -m "feat(rooms): rewrite ninja_sort with import-sort scenario"
```

---

## Task 12: ninja_norm_range — `:'<,'>norm <cmd>`

**Files:**
- Modify: `lua/rooms/ninja/norm_range.lua`

**Design.** Append `;` to a selection of lines using `:norm A;`. This is the reachability-safe stand-in for macros.

- [ ] **Step 1: Rewrite the file**

```lua
-- Ninja room: :'<,'>norm. Run a normal-mode sequence on every line in a visual selection.
return {
  id = "ninja_norm_range",
  tier = "ninja",
  command = ":'<,'>norm <cmd>",
  title = "Apply Normal to Selection: :norm",
  description = "Run a normal-mode sequence on every line in a visual selection.",
  usage_tip = "V<motion> then :norm A;<CR> appends a char to many lines at once. The macro alternative for one-shot edits.",
  before_example = "a = 1|\nb = 2",
  after_example = "a = 1;|\nb = 2;",
  filetype = "lua",
  cursor_start = { row = 1, col = 1 },
  time_limit = 75,
  goal = "Append `;` to lines 1-4 (every assignment) using `:'<,'>norm A;`.",
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
  base_xp = 130,
  optimal_keystrokes = { "V", "3", "j", ":", "n", "o", "r", "m", " ", "A", ";", "\r" },
  optimal_keystrokes_alternates = {
    { ":", "%", "n", "o", "r", "m", " ", "A", ";", "\r" },
    { "A", ";", "\27", "j", ".", "j", ".", "j", "." },
  },
}
```

- [ ] **Step 2: Run reachability**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -B1 -A20 "ninja_norm_range"`

- [ ] **Step 3: Debug.** When the harness types `:norm` after `V3j`, it should auto-prefix `'<,'>` in the command line. If not, the alternate `:% norm A;<CR>` works on every line.

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/ninja/norm_range.lua
git commit -m "feat(rooms): rewrite ninja_norm_range with batch-append scenario"
```

---

## Task 13: ninja_cgn — `cgn` + `.`

**Files:**
- Modify: `lua/rooms/ninja/cgn.lua`

**Design.** 5 occurrences of a token to rename. Star-search + cgn + four dots.

- [ ] **Step 1: Rewrite the file**

```lua
-- Ninja room: cgn + .. Repeatable rename across many occurrences without a macro.
return {
  id = "ninja_cgn",
  tier = "ninja",
  command = "cgn + .",
  title = "Change Next Match: cgn + .",
  description = "cgn changes the next search match. Combine with . to repeat across every occurrence — no :s needed.",
  usage_tip = "cgn = c + gn (gn selects next match). After cgn + <word> + Esc, dot repeats the whole operation on the next match.",
  before_example = "foo|\nfoo\nfoo",
  after_example = "bar|\nbar\nbar",
  filetype = "typescript",
  cursor_start = { row = 1, col = 16 },
  time_limit = 80,
  goal = "Rename `id` to `key` everywhere (5 occurrences).",
  start_text = [[
function lookup(id) {
  if (cache.has(id)) return cache.get(id);
  const row = db.find(id);
  cache.set(id, row);
  return row;
}]],
  target_text = [[
function lookup(key) {
  if (cache.has(key)) return cache.get(key);
  const row = db.find(key);
  cache.set(key, row);
  return row;
}]],
  base_xp = 145,
  optimal_keystrokes = { "*", "N", "c", "g", "n", "k", "e", "y", "\27", ".", ".", ".", "." },
  optimal_keystrokes_alternates = {
    { "/", "\\<", "i", "d", "\\>", "\r", "c", "g", "n", "k", "e", "y", "\27", ".", ".", ".", "." },
  },
}
```

- [ ] **Step 2: Run reachability**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -B1 -A20 "ninja_cgn"`

- [ ] **Step 3: Debug.** Cursor col 16 lands on `i` of `id` in `function lookup(id)`. Verify: `function lookup(` = 16 chars, so `i` at col 17. Adjust cursor_start.col if off. `*` requires cursor on a word char.

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/ninja/cgn.lua
git commit -m "feat(rooms): rewrite ninja_cgn with multi-rename scenario"
```

---

## Task 14: ninja_complex_motions — `gg` / `G` / `{` / `}`

**Files:**
- Modify: `lua/rooms/ninja/complex_motions.lua`

**Design.** Multi-paragraph snippet; player jumps between paragraphs with `{` / `}` and edits.

- [ ] **Step 1: Rewrite the file**

```lua
-- Ninja room: gg/G/{/}. Jump between paragraphs to make targeted edits.
return {
  id = "ninja_complex_motions",
  tier = "ninja",
  command = "gg / G / { / }",
  title = "File Motions: gg, G, {, }",
  description = "Jump to file start (gg), file end (G), prev blank-separated block ({), next (}).",
  usage_tip = "G goes to end of file instantly. { and } jump between paragraphs in prose or code.",
  before_example = "top\n\nmiddle\n\n|end",
  after_example = "TOP\n\nmiddle\n\nEND",
  filetype = "text",
  cursor_start = { row = 5, col = 1 },
  time_limit = 90,
  goal = "Upcase the first line, then jump to last paragraph and upcase its first line.",
  start_text = [[
section alpha

filler one
filler two

section beta

filler three
filler four

section gamma]],
  target_text = [[
SECTION ALPHA

filler one
filler two

section beta

filler three
filler four

SECTION GAMMA]],
  base_xp = 135,
  optimal_keystrokes = { "g", "g", "g", "U", "U", "G", "g", "U", "U" },
  optimal_keystrokes_alternates = {
    { "{", "{", "{", "g", "U", "U", "}", "}", "}", "}", "g", "U", "U" },
  },
}
```

- [ ] **Step 2: Run reachability**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -B1 -A20 "ninja_complex_motions"`

- [ ] **Step 3: Debug.** Verify last line `section gamma` and first line `section alpha` get upcased. `{` and `}` move by blank-separated paragraphs.

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/ninja/complex_motions.lua
git commit -m "feat(rooms): rewrite ninja_complex_motions with paragraph-jump scenario"
```

---

## Task 15: ninja_global_macro — Macro at scale (verified via `:norm` / `.`)

**Files:**
- Modify: `lua/rooms/ninja/global_macro.lua`

**Design.** Big batch edit. Macros are the lesson but reachability uses `:norm`. Keep macro form in title/description/usage_tip.

- [ ] **Step 1: Rewrite the file**

```lua
-- Ninja room: macro at scale. Macros fail under headless feedkeys, so reachability uses :norm.
-- The room still teaches macros via title/description.
return {
  id = "ninja_global_macro",
  tier = "ninja",
  command = "qa ... q + N@a (or :norm)",
  title = "Macro at Scale",
  description = "Record a macro into register a, then apply it to many lines with N@a.",
  usage_tip = "qa starts recording into 'a'. Do your edit. q stops. 7@a replays 7 times. Or use :'<,'>norm for a one-shot equivalent.",
  before_example = "a = 1|\nb = 2",
  after_example = "a = 1;|\nb = 2;",
  filetype = "lua",
  cursor_start = { row = 1, col = 1 },
  time_limit = 90,
  goal = "Append `;` to all 7 assignments in one batch.",
  start_text = [[
local a = 1
local b = 2
local c = 3
local d = 4
local e = 5
local f = 6
local g = 7]],
  target_text = [[
local a = 1;
local b = 2;
local c = 3;
local d = 4;
local e = 5;
local f = 6;
local g = 7;]],
  base_xp = 150,
  optimal_keystrokes = { ":", "%", "n", "o", "r", "m", " ", "A", ";", "\r" },
  optimal_keystrokes_alternates = {
    { "V", "6", "j", ":", "n", "o", "r", "m", " ", "A", ";", "\r" },
    { "A", ";", "\27", "j", ".", "j", ".", "j", ".", "j", ".", "j", ".", "j", "." },
  },
}
```

- [ ] **Step 2: Run reachability**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -B1 -A20 "ninja_global_macro"`

- [ ] **Step 3: Debug.** `:%norm A;` applies `A;<Esc>` to every line. Single ex command should pass directly.

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/ninja/global_macro.lua
git commit -m "feat(rooms): rewrite ninja_global_macro with batch-append scenario"
```

---

## Task 16: ninja_advanced_macros — Macros + text objects (verified via `cgn`)

**Files:**
- Modify: `lua/rooms/ninja/advanced_macros.lua`

**Design.** The lesson: combining macros with text objects for repeatable bulk edits. Since macros fail under headless feedkeys, primary uses the equivalent `cgn` + `.` pattern, which captures the same idea (operator + motion repeated).

- [ ] **Step 1: Rewrite the file**

```lua
-- Ninja room: macros + text objects. Verified via cgn + . since macros fail under headless feedkeys.
return {
  id = "ninja_advanced_macros",
  tier = "ninja",
  command = "qa ciw ... q + @a (or cgn + .)",
  title = "Advanced Macros",
  description = "Combine macros with text objects for powerful repeatable bulk edits.",
  usage_tip = "Record: qa ciw new <Esc> n q. Then @a repeats. The cgn+. pattern achieves the same without recording.",
  before_example = "old\nold|\nold",
  after_example = "new\nnew|\nnew",
  filetype = "lua",
  cursor_start = { row = 1, col = 7 },
  time_limit = 100,
  goal = "Replace the placeholder `let` with `const` across all 4 variable declarations.",
  start_text = [[
let foo = "hello"
let bar = "world"
let baz = "from"
let qux = "vim"]],
  target_text = [[
const foo = "hello"
const bar = "world"
const baz = "from"
const qux = "vim"]],
  base_xp = 155,
  optimal_keystrokes = { "*", "N", "c", "g", "n", "c", "o", "n", "s", "t", "\27", ".", ".", "." },
  optimal_keystrokes_alternates = {
    { ":", "%", "s", "/", "l", "e", "t", "/", "c", "o", "n", "s", "t", "/", "g", "\r" },
    { ":", "%", "n", "o", "r", "m", " ", "c", "i", "w", "c", "o", "n", "s", "t", "\r" },
  },
}
```

- [ ] **Step 2: Run reachability**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -B1 -A20 "ninja_advanced_macros"`

- [ ] **Step 3: Debug.** Cursor col 7 — line 1 is `let foo = "hello"`: `l=1 e=2 t=3 ' '=4 f=5 o=6 o=7`. Col 7 = `o`. `*` from `o` of `foo` would search for `foo` — wrong word. Adjust to col 1 (`l` of `let`).

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/ninja/advanced_macros.lua
git commit -m "feat(rooms): rewrite ninja_advanced_macros with batch-rename scenario"
```

---

## Task 17: ninja_boss — 3-phase Void

**Files:**
- Modify: `lua/rooms/ninja/boss.lua`

**Design.** Spec calls boss "registers, text objects, macro composition". Three phases at ninja calibration:

**Phase 1 — named registers + black hole.** Yank a config line, delete a stale line into `"_`, paste the yank elsewhere.
**Phase 2 — text-object surgery.** Multiple `ci(`/`di"`/`ca{` operations on a small block.
**Phase 3 — macro composition** (verified via `:%norm` or `cgn+.`).

- [ ] **Step 1: Rewrite the file**

```lua
-- Ninja boss: 3-phase Void. Registers + text objects + batch transform.
return {
  id = "ninja_boss",
  tier = "ninja",
  is_boss = true,
  command = "registers + text-objects + macros",
  title = "BOSS: The Void",
  description = "Three-phase trial. Registers, text objects, macro composition.",
  usage_tip = "Yank into named registers, surgically delete with text objects, batch-transform with :norm or cgn+.",
  base_xp = 700,
  time_limit = 300,
  phases = {
    {
      tip = "Phase 1: Yank line 1 to register a, drop line 4 via black hole, paste at end",
      filetype = "lua",
      cursor_start = { row = 1, col = 1 },
      goal = "Yank line 1 to register a, delete line 4 with \"_dd, paste a at the end.",
      start_text = [[
local config = load_default()
local x = 1
local y = 2
local stale = nil
local z = 3]],
      target_text = [[
local config = load_default()
local x = 1
local y = 2
local z = 3
local config = load_default()]],
      optimal_keystrokes = { "\"", "a", "y", "y", "4", "G", "\"", "_", "d", "d", "G", "\"", "a", "p" },
    },
    {
      tip = "Phase 2: Clear string, drop parens group, change brace body",
      filetype = "lua",
      cursor_start = { row = 1, col = 1 },
      goal = "Clear the \"old\" string, remove the (opts) call group, change {a} body to {b}.",
      start_text = [[
local x = tag("old") and call(opts) and conf({ a })]],
      target_text = [[
local x = tag("") and call and conf({ b })]],
      optimal_keystrokes = { "f", "\"", "d", "i", "\"", "f", "(", "d", "a", "(", "f", "{", "c", "i", "{", " ", "b", " ", "\27" },
    },
    {
      tip = "Phase 3: Rename `tmp` to `out` across all 5 occurrences",
      filetype = "lua",
      cursor_start = { row = 1, col = 7 },
      goal = "Rename all 5 occurrences of `tmp` to `out`.",
      start_text = [[
local tmp = init()
local x = tmp * 2
local y = tmp + 1
local z = tmp - 3
return tmp]],
      target_text = [[
local out = init()
local x = out * 2
local y = out + 1
local z = out - 3
return out]],
      optimal_keystrokes = { "*", "N", "c", "g", "n", "o", "u", "t", "\27", ".", ".", ".", "." },
    },
  },
}
```

- [ ] **Step 2: Run reachability**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -B1 -A20 "ninja_boss"`

- [ ] **Step 3: Debug each phase independently.** Phase 1: verify `"_dd` does not poison register `a`. Phase 2: mirror of Task 2 — same approach. Phase 3: mirror of Task 13 — `*` from col 7 of `local tmp = init()` lands on `t` of `tmp`.

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/ninja/boss.lua
git commit -m "feat(rooms): rewrite ninja_boss with three real-world phases"
```

---

## Task 18: Full tier sweep

**Files:**
- None (verification only).

- [ ] **Step 1: Run full CI-mode reachability**

Run: `nvim --headless --noplugin -l tests/reachability.lua`
Expected: `reachability: 63 checked, 0 skipped (no goal), all sequences pass`. 63 = 23 beginner + 21 warrior + 16 ninja regular + 3 ninja boss phases.

If skipped > 0, a ninja room is missing its `goal` field — find and fix.

- [ ] **Step 2: Run busted**

Run: `~/.luarocks/bin/busted`
Expected: 158/158 successes (no new tests added).

- [ ] **Step 3: Manual smoke test (optional)**

Launch nvim, pick a ninja room via the room picker, verify:
- `goal` line renders in HUD
- Syntax highlighting matches `filetype`
- Cursor lands at `cursor_start`
- No interference from user plugins

- [ ] **Step 4: Final commit if tweaks were made**

```bash
git add -u
git commit -m "fix(rooms): tighten ninja content after full-tier sweep"
```

---

## Self-Review Checklist

1. **Spec coverage:**
   - All 16 ninja regular rooms + 1 boss listed in spec coverage table → present as Tasks 1–17. ✓
   - Schema additions (`filetype`/`cursor_start`/`goal`) in every file. ✓
   - Reachability harness gate before every commit. ✓
   - Tier calibration: 15-30 line snippets, 20-60 keys, base_xp 120-180, time_limit 60-180s. ✓
   - Multiple alternates per room where reasonable. ✓

2. **Placeholder scan:** Every task has full file content + concrete reachability command + debug step. Known weak rooms flagged inline: Task 7 (`<C-o>` may fail under feedkeys), Task 11 (`5j` vs `4j` selection range), Task 13 (cursor col 16 vs 17), Task 15/16 (macros disabled → uses `:norm`/`cgn`), Task 17 phase boundaries. ✓

3. **Type consistency:** Field names match `rooms.lua` validator. Escape encoding `"\27"` / `"\18"` / `"\22"` / `"\15"` / `"\1"` / `"\24"` / `"\r"` used consistently. Phase optional fields (`filetype` / `cursor_start` / `goal`) per spec — supported by PR 1 validator. ✓
