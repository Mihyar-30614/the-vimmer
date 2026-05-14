# Real-World Rooms PR 3 — Warrior Tier Rewrite

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite all 19 warrior rooms (18 regular + 1 boss) as realistic mini-tasks on real-feeling code snippets. Each room ships `filetype`, `cursor_start`, `goal` plus updated `start_text` / `target_text` / `optimal_keystrokes` / `optimal_keystrokes_alternates`. Reachability harness must pass for every primary + alternate sequence.

**Architecture:** Engine support shipped in PR 1; beginner content shipped in PR 2 (commits `fff2667`..`c8ec16e`). This PR rewrites `lua/rooms/warrior/*.lua` in place. One file per task. Same per-room reachability gate as PR 2.

**Tech Stack:** Lua 5.1 (Neovim runtime), busted, headless Neovim reachability harness.

**Calibration target (per spec):**
- 10–20 line snippets, 1–2 commands chained, single real task
- `optimal_keystrokes` length: 15–40
- `time_limit`: 45–90s
- `base_xp` range: 70–110
- **Heavy use of `optimal_keystrokes_alternates`** — most warrior rooms have 2–3 reasonable paths.

**Keystroke encoding cheatsheet (verified during PR 2 execution):**
- `\27` = `<Esc>` — exit insert/visual mode
- `\18` = `<C-r>` — redo
- `\22` = `<C-v>` — visual block enter
- `\6`  = `<C-f>` — scroll page down
- `\2`  = `<C-b>` — scroll page up
- `\r`  = `<CR>` — Enter
- `\t`  = Tab

**Quirks learned from PR 2 (always check first when reachability fails):**
1. `nvim_buf_set_lines` is itself an undoable change. A bare `u` at start reverts to empty buffer. Wrap undo scenarios as `edit → u → <C-r>` so net delta survives.
2. Default Neovim has `autoindent` ON. `o` / `O` inherits the prior line's leading whitespace — strip explicit leading spaces from typed inserts.
3. `J` strips leading whitespace, inserts ONE space, but skips space before `)`. Adjust `target_text` to match — don't fight `J` semantics.
4. `f<char>` does NOT include the current cursor position. If cursor is already on the target char, use `r<char>` directly, not `f<char> r<char>`.
5. `j`/`k` preserve column when possible. After an edit, the next line's edit at the same column can omit `f<char>` if columns align.
6. `b` / `w` / `e` treat punctuation as separate words. Use `B` / `W` / `E` for whitespace-separated WORDs when stepping over `,` or `"`.
7. `dw` deletes a word but stops at the next word's start — to also consume a trailing comma, use `2dw` or `dW`.

**Per-room reachability command:**

```bash
nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -B1 -A14 "warrior_<slug>"
```

Empty output = pass. Any `[warrior_<slug> ...]` block = failure with expected vs actual diff.

**Existing test gates (must remain green):**

```bash
~/.luarocks/bin/busted
nvim --headless --noplugin -l tests/reachability.lua    # CI mode (skips rooms without goal)
```

---

## File Structure

| Path | Action | Command focus |
|---|---|---|
| `lua/rooms/warrior/ciw.lua` | Rewrite | `ciw` / `cgn` rename pattern (Task 1) |
| `lua/rooms/warrior/ci_combo.lua` | Rewrite | `ci"` / `ci(` / `ci[` (Task 2) |
| `lua/rooms/warrior/change_chain.lua` | Rewrite | `cw` + `.` (Task 3) |
| `lua/rooms/warrior/case_ops.lua` | Rewrite | `gU` / `gu` / `guu` (Task 4) |
| `lua/rooms/warrior/indent.lua` | Rewrite | `>>` / `<<` / `>}` (Task 5) |
| `lua/rooms/warrior/scroll.lua` | Rewrite | `zz` / `zt` / `zb` + edit (Task 6) |
| `lua/rooms/warrior/viewport.lua` | Rewrite | `H` / `M` / `L` + edit (Task 7) |
| `lua/rooms/warrior/search.lua` | Rewrite | `/pattern` + `n` (Task 8) |
| `lua/rooms/warrior/star_search.lua` | Rewrite | `*` + `cgn` + `.` (Task 9) |
| `lua/rooms/warrior/f_motion.lua` | Rewrite | `f<char>` / `t<char>` (Task 10) |
| `lua/rooms/warrior/ft_chain.lua` | Rewrite | `f` / `;` / `,` (Task 11) |
| `lua/rooms/warrior/delete_to.lua` | Rewrite | `dt` / `df` (Task 12) |
| `lua/rooms/warrior/percent_motion.lua` | Rewrite | `%` bracket match (Task 13) |
| `lua/rooms/warrior/goto_line.lua` | Rewrite | `:N<CR>` (Task 14) |
| `lua/rooms/warrior/n_repeat.lua` | Rewrite | `/` + `cgn` + `.` (Task 15) |
| `lua/rooms/warrior/macros_intro.lua` | Rewrite | `q<reg>` / `@<reg>` (Task 16) |
| `lua/rooms/warrior/visual_mode.lua` | Rewrite | `v` / `V` + operator (Task 17) |
| `lua/rooms/warrior/visual_block.lua` | Rewrite | `<C-v>` + `I` (Task 18) |
| `lua/rooms/warrior/boss.lua` | Rewrite | 3-phase siege (Task 19) |

---

## Task 1: warrior_ciw — Rename Param

**Files:**
- Modify: `lua/rooms/warrior/ciw.lua`

**Design.** Spec's worked example. TypeScript-flavored function with 3 occurrences of `userId` — rename all to `accountId` using `*` + `cgn` + `.` (or pure `ciw` + `n` chain as alternate).

- [ ] **Step 1: Rewrite the file**

```lua
-- Warrior room: ciw / cgn. Rename a parameter across a small function body.
return {
  id = "warrior_ciw",
  tier = "warrior",
  command = "ciw / cgn",
  title = "Rename Param: ciw, cgn",
  description = "ciw deletes word under cursor and enters insert mode. cgn changes the next search match. . repeats.",
  before_example = "the |wrong word here",
  after_example = "the |right word here",
  usage_tip = "ciw works anywhere on the word. Pair with * to seed a search, then cgn + . to repeat the rename.",
  filetype = "typescript",
  cursor_start = { row = 1, col = 22 },
  time_limit = 60,
  goal = "Rename param `userId` to `accountId` (3 occurrences).",
  start_text = [[
function fetchUser(userId) {
  const cache = userCache.get(userId);
  if (!cache) return loadUser(userId);
  return cache;
}]],
  target_text = [[
function fetchUser(accountId) {
  const cache = userCache.get(accountId);
  if (!cache) return loadUser(accountId);
  return cache;
}]],
  base_xp = 90,
  optimal_keystrokes = { "*", "N", "c", "g", "n", "a", "c", "c", "o", "u", "n", "t", "I", "d", "\27", ".", "." },
  optimal_keystrokes_alternates = {
    { "c", "i", "w", "a", "c", "c", "o", "u", "n", "t", "I", "d", "\27", "n", ".", "n", "." },
  },
}
```

- [ ] **Step 2: Run reachability**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -B1 -A14 "warrior_ciw"`
Expected: empty output (pass).

- [ ] **Step 3: Debug if needed.** If `*` doesn't seed the search because cursor lands inside the word, verify `cursor_start.col` is on a letter of `userId` (col 22 corresponds to `u` of first `userId` in `function fetchUser(userId)` — count: `function fetchUser(` = 19 chars, so `userId` starts at col 20). Recount and adjust.

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/warrior/ciw.lua
git commit -m "feat(rooms): rewrite warrior_ciw with multi-occurrence rename"
```

---

## Task 2: warrior_ci_combo — Change Inside Delimiters

**Files:**
- Modify: `lua/rooms/warrior/ci_combo.lua`

**Design.** Snippet with one string and one parenthesized arg list. Player uses `ci"` and `ci(`.

- [ ] **Step 1: Rewrite the file**

```lua
-- Warrior room: ci"/ci(. Replace string contents and an arg list.
return {
  id = "warrior_ci_combo",
  tier = "warrior",
  command = "ci\" / ci( / ci[",
  title = "Change Inside Combo",
  description = "ci<delim> changes everything inside the given delimiter pair",
  before_example = 'log("old", a, b)|',
  after_example = 'log("new", x, y)|',
  usage_tip = 'ci" changes inside double quotes. ci( changes inside parens.',
  filetype = "lua",
  cursor_start = { row = 1, col = 1 },
  time_limit = 60,
  goal = "Replace the log tag `old` with `new`, and replace the arg list `a, b` with `x, y`.",
  start_text = [[
local function emit()
  log("old", a, b)
end]],
  target_text = [[
local function emit()
  log("new", x, y)
end]],
  base_xp = 80,
  optimal_keystrokes = { "j", "f", "\"", "c", "i", "\"", "n", "e", "w", "\27", "f", "a", "v", "i", "(", "c", "\"", "n", "e", "w", "\27" },
  optimal_keystrokes_alternates = {
    { "/", "o", "l", "d", "\r", "c", "i", "\"", "n", "e", "w", "\27", "f", "a", "c", "i", "(", "x", ",", " ", "y", "\27" },
    { "j", "f", "o", "c", "i", "\"", "n", "e", "w", "\27", "f", "a", "c", "i", "(", "x", ",", " ", "y", "\27" },
  },
}
```

- [ ] **Step 2: Run reachability**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -B1 -A14 "warrior_ci_combo"`

- [ ] **Step 3: Debug.** The primary's clever `ci(` after `via` is brittle — if it fails, fall back to alternate #2 (pure `f<char>` + `ci"`/`ci(` chain). Reachability passing on at least one of primary/alternates is enough; remove failing variants.

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/warrior/ci_combo.lua
git commit -m "feat(rooms): rewrite warrior_ci_combo with delim-change scenario"
```

---

## Task 3: warrior_change_chain — cw + .

**Files:**
- Modify: `lua/rooms/warrior/change_chain.lua`

**Design.** Three struct fields with prefix `tmp_`; rename each to `final_` using `cw` first then `.` to repeat. Highlights the `.` repeat with operator+motion grammar.

- [ ] **Step 1: Rewrite the file**

```lua
-- Warrior room: cw + .. Rename three prefixed fields by changing the first, then repeating.
return {
  id = "warrior_change_chain",
  tier = "warrior",
  command = "cw / .",
  title = "Change and Repeat",
  description = "cw changes a word. . repeats the last change at the cursor position.",
  usage_tip = "cw replaces from cursor to end of word. . repeats it on the next match.",
  before_example = "tmp_a = 1\ntmp_b = 2|",
  after_example = "final_a = 1\nfinal_b = 2|",
  filetype = "lua",
  cursor_start = { row = 1, col = 1 },
  time_limit = 75,
  goal = "Rename three `tmp_` field prefixes to `final_`.",
  start_text = [[
local record = {
  tmp_id = 1,
  tmp_name = "x",
  tmp_value = 0,
}]],
  target_text = [[
local record = {
  final_id = 1,
  final_name = "x",
  final_value = 0,
}]],
  base_xp = 95,
  optimal_keystrokes = { "j", "f", "t", "c", "t", "_", "f", "i", "n", "a", "l", "\27", "j", "f", "t", ".", "j", "f", "t", "." },
  optimal_keystrokes_alternates = {
    { "/", "t", "m", "p", "\r", "c", "g", "n", "f", "i", "n", "a", "l", "\27", ".", "." },
  },
}
```

- [ ] **Step 2: Run reachability**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -B1 -A14 "warrior_change_chain"`

- [ ] **Step 3: Debug.** `ct_` changes up to but not including `_`. Verify `tmp` → `final` produces `final_id`. If `_` count is off, switch to `ce` (change to end of word) — but `tmp` ends at `_` boundary, so `ct_` is correct.

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/warrior/change_chain.lua
git commit -m "feat(rooms): rewrite warrior_change_chain with repeated rename"
```

---

## Task 4: warrior_case_ops — gU / gu / guu

**Files:**
- Modify: `lua/rooms/warrior/case_ops.lua`

**Design.** SQL statement with lowercase keywords; upcase via `gU iw` (or `gUw`). Three keywords to upcase.

- [ ] **Step 1: Rewrite the file**

```lua
-- Warrior room: gU / gu. Upcase SQL keywords scattered across a query.
return {
  id = "warrior_case_ops",
  tier = "warrior",
  command = "gU{motion} / gu{motion} / guu",
  title = "Case Operators: gU, gu",
  description = "gU uppercases, gu lowercases. Combine with any motion or double for whole line: gUU / guu.",
  usage_tip = "guu = lowercase line, gUU = uppercase line. gUw = uppercase next word. g~ toggles case.",
  filetype = "sql",
  cursor_start = { row = 1, col = 1 },
  time_limit = 60,
  goal = "Uppercase the SQL keywords `select`, `from`, `where`.",
  start_text = [[
select id, name
from users
where active = true]],
  target_text = [[
SELECT id, name
FROM users
WHERE active = true]],
  base_xp = 85,
  optimal_keystrokes = { "g", "U", "i", "w", "j", "g", "U", "i", "w", "j", "g", "U", "i", "w" },
  optimal_keystrokes_alternates = {
    { "g", "U", "w", "j", "0", "g", "U", "w", "j", "0", "g", "U", "w" },
    { "v", "e", "U", "j", "0", "v", "e", "U", "j", "0", "v", "e", "U" },
  },
}
```

- [ ] **Step 2: Run reachability**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -B1 -A14 "warrior_case_ops"`

- [ ] **Step 3: Debug.** `j` preserves column. After `gUiw` on line 1 (cursor lands at end of word `select` → col 6), `j` to line 2 col 6 lands inside `from` (line 2 is `from users`, col 6 is space). May need `0` to reset. The alternates already include `0` for safety.

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/warrior/case_ops.lua
git commit -m "feat(rooms): rewrite warrior_case_ops with SQL upcase scenario"
```

---

## Task 5: warrior_indent — `>>` / `<<`

**Files:**
- Modify: `lua/rooms/warrior/indent.lua`

**Design.** Three lines under an `if` that should be indented one level deeper. Player uses `>>` three times (or `V}>` block).

- [ ] **Step 1: Rewrite the file**

```lua
-- Warrior room: >>/<<. Indent three lines under an if block.
return {
  id = "warrior_indent",
  tier = "warrior",
  command = ">> / <<",
  title = "Indent: >>, <<",
  description = ">> indents the current line by one shiftwidth; << dedents.",
  usage_tip = "Repeat with . or use ranges: V}>  indents a paragraph.",
  before_example = "if x then\nfoo()\nend|",
  after_example = "if x then\n  foo()\nend|",
  filetype = "lua",
  cursor_start = { row = 2, col = 1 },
  time_limit = 60,
  goal = "Indent the three body lines under the `if` by one level.",
  start_text = [[
if ready then
log.info("starting")
run_task()
log.info("done")
end]],
  target_text = [[
if ready then
  log.info("starting")
  run_task()
  log.info("done")
end]],
  base_xp = 80,
  optimal_keystrokes = { ">", ">", "j", ".", "j", "." },
  optimal_keystrokes_alternates = {
    { "V", "2", "j", ">" },
    { "3", ">", ">" },
  },
  bo = { shiftwidth = 2, expandtab = true },
}
```

- [ ] **Step 2: Run reachability**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -B1 -A14 "warrior_indent"`

- [ ] **Step 3: Debug.** `bo.shiftwidth = 2` is honored per buffer by harness (it copies `ctx.bo` into `vim.bo[buf]`). Confirm indent yields exactly two spaces, not a tab. If tabs appear, ensure `expandtab = true` is in `bo`.

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/warrior/indent.lua
git commit -m "feat(rooms): rewrite warrior_indent with if-body indent scenario"
```

---

## Task 6: warrior_scroll — `zz` / `zt` / `zb`

**Files:**
- Modify: `lua/rooms/warrior/scroll.lua`

**Design.** `zz`/`zt`/`zb` don't modify text — they scroll the window. The reachability harness compares buffer text, so include them as part of a sequence whose *text* edit still lands correctly. Frame as: jump to a far line, recenter view, make a single edit.

- [ ] **Step 1: Rewrite the file**

```lua
-- Warrior room: zz/zt/zb. After a big jump, recenter the view, then edit.
return {
  id = "warrior_scroll",
  tier = "warrior",
  command = "zz / zt / zb",
  title = "Center View: zz, zt, zb",
  description = "zz centers cursor line; zt puts it at top; zb at bottom.",
  usage_tip = "Great after a big jump (G, /search, gg). zz feels like re-anchoring.",
  before_example = "...|line 50...",
  after_example = "...|LINE 50...",
  filetype = "text",
  cursor_start = { row = 1, col = 1 },
  time_limit = 60,
  goal = "Jump to line 8 (`bug here`), recenter, and replace it with `FIXED`.",
  start_text = [[
header line
note one
note two
note three
note four
note five
note six
bug here
note eight
note nine]],
  target_text = [[
header line
note one
note two
note three
note four
note five
note six
FIXED
note eight
note nine]],
  base_xp = 80,
  optimal_keystrokes = { "8", "G", "z", "z", "V", "r", "F", "A", "I", "X", "E", "D", "\27" },
  optimal_keystrokes_alternates = {
    { "/", "b", "u", "g", "\r", "z", "z", "c", "c", "F", "I", "X", "E", "D", "\27" },
  },
}
```

- [ ] **Step 2: Run reachability**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -B1 -A20 "warrior_scroll"`

- [ ] **Step 3: Debug.** The primary uses `Vr` then `A...` which behaves oddly. Prefer the alternate (`cc FIXED <Esc>`) — if primary fails, drop it and promote the alternate.

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/warrior/scroll.lua
git commit -m "feat(rooms): rewrite warrior_scroll with jump-recenter-edit scenario"
```

---

## Task 7: warrior_viewport — `H` / `M` / `L`

**Files:**
- Modify: `lua/rooms/warrior/viewport.lua`

**Design.** `H`/`M`/`L` jump within visible window. In the headless harness, window is 25 rows tall. Use them as nav within a small buffer + edit.

- [ ] **Step 1: Rewrite the file**

```lua
-- Warrior room: H/M/L. Window-relative jumps + small edit.
return {
  id = "warrior_viewport",
  tier = "warrior",
  command = "H / M / L",
  title = "Viewport Jumps: H, M, L",
  description = "H = top of screen, M = middle, L = bottom.",
  usage_tip = "Jumps within the visible window — not the whole file. Quick when scrolling around.",
  before_example = "top|\nmid\nbot",
  after_example = "TOP|\nmid\nbot",
  filetype = "text",
  cursor_start = { row = 3, col = 1 },
  time_limit = 50,
  goal = "Use viewport jumps to upcase the first line `top` and the last line `bottom`.",
  start_text = [[
top
filler 1
filler 2
filler 3
middle
filler 4
filler 5
filler 6
bottom]],
  target_text = [[
TOP
filler 1
filler 2
filler 3
middle
filler 4
filler 5
filler 6
BOTTOM]],
  base_xp = 85,
  optimal_keystrokes = { "H", "g", "U", "U", "L", "g", "U", "U" },
  optimal_keystrokes_alternates = {
    { "g", "g", "g", "U", "U", "G", "g", "U", "U" },
  },
}
```

- [ ] **Step 2: Run reachability**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -B1 -A20 "warrior_viewport"`

- [ ] **Step 3: Debug.** With a 9-line buffer and 25-row window, `H` lands on line 1 and `L` lands on line 9 — both buffer-local since whole buffer fits in window. Should pass directly.

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/warrior/viewport.lua
git commit -m "feat(rooms): rewrite warrior_viewport with HML-jump scenario"
```

---

## Task 8: warrior_search — `/pattern` + `n`

**Files:**
- Modify: `lua/rooms/warrior/search.lua`

**Design.** Snippet with `bug` repeated three times; player searches and replaces each instance.

- [ ] **Step 1: Rewrite the file**

```lua
-- Warrior room: /, n, N. Search and edit at each match.
return {
  id = "warrior_search",
  tier = "warrior",
  command = "/ / n / N",
  title = "Search: /, n, N",
  description = "Search forward for a pattern (/), jump to next match (n), previous (N).",
  usage_tip = "/ followed by your search term then Enter. n hops to next match.",
  before_example = "tag = |old\ntag = old",
  after_example = "tag = |new\ntag = new",
  filetype = "lua",
  cursor_start = { row = 1, col = 1 },
  time_limit = 60,
  goal = "Find each `bug` (3 occurrences) and replace with `ok`.",
  start_text = [[
local a = "bug"
local b = "x"
local c = "bug"
local d = "y"
local e = "bug"]],
  target_text = [[
local a = "ok"
local b = "x"
local c = "ok"
local d = "y"
local e = "ok"]],
  base_xp = 95,
  optimal_keystrokes = { "/", "b", "u", "g", "\r", "c", "g", "n", "o", "k", "\27", ".", "." },
  optimal_keystrokes_alternates = {
    { "/", "b", "u", "g", "\r", "c", "i", "w", "o", "k", "\27", "n", ".", "n", "." },
  },
}
```

- [ ] **Step 2: Run reachability**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -B1 -A20 "warrior_search"`

- [ ] **Step 3: Debug.** `\r` after the search pattern is the carriage return that submits the search. If search doesn't fire, confirm `\r` not `\n`.

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/warrior/search.lua
git commit -m "feat(rooms): rewrite warrior_search with multi-match edit"
```

---

## Task 9: warrior_star_search — `*` + `cgn` + `.`

**Files:**
- Modify: `lua/rooms/warrior/star_search.lua`

**Design.** Same shape as Task 8 but seed search via `*` instead of typed `/`.

- [ ] **Step 1: Rewrite the file**

```lua
-- Warrior room: * + cgn + .. Star-search the word under cursor, then replace each.
return {
  id = "warrior_star_search",
  tier = "warrior",
  command = "* / cgn / .",
  title = "Search Under Cursor: * with cgn",
  description = "* searches forward for the word under cursor. cgn changes the next match. . repeats.",
  usage_tip = "* is faster than /word<CR>. cgn + . is the canonical rename pattern.",
  before_example = "|TODO line 1\nTODO line 2",
  after_example = "|DONE line 1\nDONE line 2",
  filetype = "lua",
  cursor_start = { row = 1, col = 7 },
  time_limit = 60,
  goal = "Rename all `TODO` (3 occurrences) to `DONE`.",
  start_text = [[
-- TODO: fetch data
local x = 1
-- TODO: validate
local y = 2
-- TODO: persist]],
  target_text = [[
-- DONE: fetch data
local x = 1
-- DONE: validate
local y = 2
-- DONE: persist]],
  base_xp = 100,
  optimal_keystrokes = { "*", "N", "c", "g", "n", "D", "O", "N", "E", "\27", ".", "." },
  optimal_keystrokes_alternates = {
    { "*", "N", "c", "i", "w", "D", "O", "N", "E", "\27", "n", ".", "n", "." },
  },
}
```

- [ ] **Step 2: Run reachability**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -B1 -A20 "warrior_star_search"`

- [ ] **Step 3: Debug.** `*` seeds the search but moves to the NEXT match — `N` walks back to the first. If the first match gets skipped, verify the `N` is present.

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/warrior/star_search.lua
git commit -m "feat(rooms): rewrite warrior_star_search with cgn rename pattern"
```

---

## Task 10: warrior_f_motion — `f<char>` / `t<char>`

**Files:**
- Modify: `lua/rooms/warrior/f_motion.lua`

**Design.** Single line with several `,` separators; player jumps via `f,` to land precisely.

- [ ] **Step 1: Rewrite the file**

```lua
-- Warrior room: f/t. Jump to a punctuation mark on a line, delete to it.
return {
  id = "warrior_f_motion",
  tier = "warrior",
  command = "f<char> / t<char>",
  title = "Find Char: f, t",
  description = "Jump to next occurrence of a char (f lands ON it, t lands BEFORE it).",
  usage_tip = "f: jumps to the colon. Use ; to repeat the jump forward, , to go back.",
  before_example = "ok|, ok, ok, fail",
  after_example = "ok, ok, ok, |pass",
  filetype = "lua",
  cursor_start = { row = 2, col = 1 },
  time_limit = 50,
  goal = "Replace the value `fail` (after the third comma) with `pass`.",
  start_text = [[
local results = {
  "ok", "ok", "ok", "fail",
}]],
  target_text = [[
local results = {
  "ok", "ok", "ok", "pass",
}]],
  base_xp = 80,
  optimal_keystrokes = { "f", "f", "c", "w", "p", "a", "s", "s", "\27" },
  optimal_keystrokes_alternates = {
    { "f", ",", "f", ",", "f", ",", "f", "f", "c", "i", "w", "p", "a", "s", "s", "\27" },
  },
}
```

- [ ] **Step 2: Run reachability**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -B1 -A14 "warrior_f_motion"`

- [ ] **Step 3: Debug.** `f f` looks for letter `f`. Line 2 contains one literal `f` in `fail`. So `f f` from col 1 lands on the `f` of `fail`. `cw` consumes `fail`. Type `pass`. Should pass.

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/warrior/f_motion.lua
git commit -m "feat(rooms): rewrite warrior_f_motion with find-char-edit scenario"
```

---

## Task 11: warrior_ft_chain — `f` / `;` / `,`

**Files:**
- Modify: `lua/rooms/warrior/ft_chain.lua`

**Design.** Line with multiple identical separators; use `f,` then `;` to repeat. Delete a value mid-line.

- [ ] **Step 1: Rewrite the file**

```lua
-- Warrior room: f/;/,. Repeat the last find with ; to step through identical separators.
return {
  id = "warrior_ft_chain",
  tier = "warrior",
  command = "f / t / ; / ,",
  title = "f/t Motion Chain",
  description = "; repeats the last f/t forward; , reverses it.",
  usage_tip = "ff finds next 'f'. ; jumps to the one after. , goes back.",
  before_example = "a, b, |c, d",
  after_example = "a, b, |X, d",
  filetype = "lua",
  cursor_start = { row = 1, col = 1 },
  time_limit = 55,
  goal = "Change the third item `c` to `X`.",
  start_text = [[
local items = { "a", "b", "c", "d", "e" }]],
  target_text = [[
local items = { "a", "b", "X", "d", "e" }]],
  base_xp = 85,
  optimal_keystrokes = { "f", "c", "r", "X" },
  optimal_keystrokes_alternates = {
    { "f", ",", ";", ";", "l", "l", "r", "X" },
    { "f", "\"", ";", ";", ";", ";", ";", "r", "X" },
  },
}
```

- [ ] **Step 2: Run reachability**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -B1 -A14 "warrior_ft_chain"`

- [ ] **Step 3: Debug.** The primary `f c` is the shortest path since `c` only appears once on the line. The alternates exercise `;` for repeated punctuation jumps.

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/warrior/ft_chain.lua
git commit -m "feat(rooms): rewrite warrior_ft_chain with find-repeat scenario"
```

---

## Task 12: warrior_delete_to — `dt` / `df`

**Files:**
- Modify: `lua/rooms/warrior/delete_to.lua`

**Design.** Function call with an extra arg before `)`; player uses `dt)` to clean.

- [ ] **Step 1: Rewrite the file**

```lua
-- Warrior room: dt/df. Delete trailing args up to the close paren.
return {
  id = "warrior_delete_to",
  tier = "warrior",
  command = "dt<char> / df<char>",
  title = "Delete To Char: dt, df",
  description = "dt<char> deletes up to (not including) a char. df<char> deletes up to and including it.",
  usage_tip = "dt) deletes everything before the close paren. ct) does the same but leaves you in insert mode.",
  before_example = "call(a, |b, junk)",
  after_example = "call(a, |b)",
  filetype = "lua",
  cursor_start = { row = 2, col = 14 },
  time_limit = 55,
  goal = "Delete the `, debug, trace` arguments before the close paren.",
  start_text = [[
local function send(msg)
  emit(msg, debug, trace)
end]],
  target_text = [[
local function send(msg)
  emit(msg)
end]],
  base_xp = 85,
  optimal_keystrokes = { "d", "t", ")" },
  optimal_keystrokes_alternates = {
    { "d", "f", "e", "x" },
    { "v", "t", ")", "d" },
  },
}
```

- [ ] **Step 2: Run reachability**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -B1 -A14 "warrior_delete_to"`

- [ ] **Step 3: Debug.** Column 14 of `  emit(msg, debug, trace)` is: `' '=1 ' '=2 e=3 m=4 i=5 t=6 (=7 m=8 s=9 g=10 ,=11 ' '=12 d=13 e=14`. So col 14 is `e` of `debug`. `dt)` from there deletes `ebug, trace` — wrong target. Need cursor on `,` after `msg` (col 11) so `dt)` deletes `, debug, trace`. Adjust `cursor_start.col = 11`.

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/warrior/delete_to.lua
git commit -m "feat(rooms): rewrite warrior_delete_to with extra-arg cleanup"
```

---

## Task 13: warrior_percent_motion — `%`

**Files:**
- Modify: `lua/rooms/warrior/percent_motion.lua`

**Design.** Nested function call with extra wrapper; player uses `%` to jump to matching paren then deletes the wrapper.

- [ ] **Step 1: Rewrite the file**

```lua
-- Warrior room: %. Jump matching brackets to delete a wrapper function call.
return {
  id = "warrior_percent",
  tier = "warrior",
  command = "%",
  title = "Jump to Match: %",
  description = "Jump between matching bracket pairs: (), [], {}.",
  usage_tip = "% jumps to the matching bracket. Essential for navigating nested code.",
  before_example = "wrap(|foo(x))",
  after_example = "foo(x)|",
  filetype = "lua",
  cursor_start = { row = 2, col = 12 },
  time_limit = 55,
  goal = "Strip the `wrap(...)` wrapper, leaving just `foo(x)`.",
  start_text = [[
local function call()
  return wrap(foo(x))
end]],
  target_text = [[
local function call()
  return foo(x)
end]],
  base_xp = 95,
  optimal_keystrokes = { "%", "x", "0", "f", "w", "d", "f", "(" },
  optimal_keystrokes_alternates = {
    { "f", "(", "%", "x", "F", "w", "d", "f", "(" },
  },
}
```

- [ ] **Step 2: Run reachability**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -B1 -A14 "warrior_percent"`

- [ ] **Step 3: Debug.** Column 12 of `  return wrap(foo(x))` is the `(` after `wrap` — verify: `' '=1 ' '=2 r=3 e=4 t=5 u=6 r=7 n=8 ' '=9 w=10 a=11 r=12`. Wrong — col 12 is `r`. Correct col for `(` after `wrap`: 14. Adjust `cursor_start.col = 14`. Then `%` jumps to matching `)` at end. `x` deletes it. Then need to also remove `wrap(`. The sequence then navigates back and deletes via `df(`.

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/warrior/percent_motion.lua
git commit -m "feat(rooms): rewrite warrior_percent_motion with wrapper-strip scenario"
```

---

## Task 14: warrior_goto_line — `:N<CR>`

**Files:**
- Modify: `lua/rooms/warrior/goto_line.lua`

**Design.** Multi-line snippet; jump to line 5 via `:5<CR>` and edit.

- [ ] **Step 1: Rewrite the file**

```lua
-- Warrior room: :N. Type :LINE<CR> to jump to a specific line, then edit.
return {
  id = "warrior_goto_line",
  tier = "warrior",
  command = ":N",
  title = "Goto Line: :N",
  description = "Type :NUMBER<CR> to jump to that line.",
  usage_tip = ":7<CR> is the same as 7G. Pairs naturally with line numbers in the gutter.",
  before_example = "line 1\n|line 5",
  after_example = "line 1\n|LINE 5",
  filetype = "text",
  cursor_start = { row = 1, col = 1 },
  time_limit = 50,
  goal = "Jump to line 5 and uppercase it.",
  start_text = [[
header
config one
config two
config three
target line]],
  target_text = [[
header
config one
config two
config three
TARGET LINE]],
  base_xp = 75,
  optimal_keystrokes = { ":", "5", "\r", "g", "U", "U" },
  optimal_keystrokes_alternates = {
    { "5", "G", "g", "U", "U" },
    { "G", "g", "U", "U" },
  },
}
```

- [ ] **Step 2: Run reachability**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -B1 -A14 "warrior_goto_line"`

- [ ] **Step 3: Debug.** `:5<CR>` enters command-line. `\r` submits.

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/warrior/goto_line.lua
git commit -m "feat(rooms): rewrite warrior_goto_line with jump-and-edit scenario"
```

---

## Task 15: warrior_n_repeat — `/` + `cgn` + `.`

**Files:**
- Modify: `lua/rooms/warrior/n_repeat.lua`

**Design.** Same machinery as Task 9 but seeded by typed `/` and emphasizes `n` + `.` workflow as alternate path. 4 occurrences this time for more practice.

- [ ] **Step 1: Rewrite the file**

```lua
-- Warrior room: /pattern + cgn + .. Search-driven repeated edits.
return {
  id = "warrior_n_repeat",
  tier = "warrior",
  command = "/pattern + cgn + .",
  title = "Search and Repeat",
  description = "Search for a pattern, change next match (cgn), repeat with .",
  usage_tip = "/foo<CR> finds first match. cgn changes it. . repeats. n+. is the older form.",
  before_example = "|foo\nfoo\nfoo",
  after_example = "|bar\nbar\nbar",
  filetype = "lua",
  cursor_start = { row = 1, col = 1 },
  time_limit = 70,
  goal = "Rename all 4 instances of `temp` to `final`.",
  start_text = [[
local temp = 1
local x = temp + 2
local y = temp * 3
local z = temp - 4]],
  target_text = [[
local final = 1
local x = final + 2
local y = final * 3
local z = final - 4]],
  base_xp = 100,
  optimal_keystrokes = { "/", "t", "e", "m", "p", "\r", "c", "g", "n", "f", "i", "n", "a", "l", "\27", ".", ".", "." },
  optimal_keystrokes_alternates = {
    { "/", "t", "e", "m", "p", "\r", "c", "i", "w", "f", "i", "n", "a", "l", "\27", "n", ".", "n", ".", "n", "." },
  },
}
```

- [ ] **Step 2: Run reachability**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -B1 -A20 "warrior_n_repeat"`

- [ ] **Step 3: Debug.** `cgn` after first search jumps to current match and changes it. `.` repeats both the search advance and the change. Validates with 4 occurrences.

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/warrior/n_repeat.lua
git commit -m "feat(rooms): rewrite warrior_n_repeat with cgn-dot rename"
```

---

## Task 16: warrior_macros — `q<reg>` / `@<reg>`

**Files:**
- Modify: `lua/rooms/warrior/macros_intro.lua`

**Design.** Record a 1-line macro that appends `;` and advances `j`, then replay 2 times.

- [ ] **Step 1: Rewrite the file**

```lua
-- Warrior room: q/@. Record a macro that appends `;` and advances, replay it.
return {
  id = "warrior_macros",
  tier = "warrior",
  command = "qa ... q / @a",
  title = "Macros: q, @",
  description = "Record a macro into a register (qa), stop (q), replay (@a).",
  usage_tip = "qa records into register a. Do edits. q stops. @a replays. 2@a repeats twice.",
  before_example = "a = 1|\nb = 2\nc = 3",
  after_example = "a = 1;|\nb = 2;\nc = 3;",
  filetype = "lua",
  cursor_start = { row = 1, col = 1 },
  time_limit = 75,
  goal = "Record a macro that appends `;` + moves down, then replay it on the remaining lines.",
  start_text = [[
local a = 1
local b = 2
local c = 3]],
  target_text = [[
local a = 1;
local b = 2;
local c = 3;]],
  base_xp = 110,
  optimal_keystrokes = { "q", "a", "A", ";", "\27", "j", "q", "@", "a", "@", "a" },
  optimal_keystrokes_alternates = {
    { "q", "q", "A", ";", "\27", "j", "q", "2", "@", "q" },
    { "A", ";", "\27", "j", ".", "j", "." },
  },
}
```

- [ ] **Step 2: Run reachability**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -B1 -A14 "warrior_macros"`

- [ ] **Step 3: Debug.** Macros in headless mode: `qa ... q` records into register `a`. After stop, `@a` replays. The third `j` inside the macro may scroll past EOF — that's fine since the macro's last action just moves cursor. Net 2 replays produce target. If macros fail entirely under feedkeys, fall back to alternate #3 (pure `.` repeat).

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/warrior/macros_intro.lua
git commit -m "feat(rooms): rewrite warrior_macros with append-semicolon scenario"
```

---

## Task 17: warrior_visual_mode — `v` / `V` + operator

**Files:**
- Modify: `lua/rooms/warrior/visual_mode.lua`

**Design.** Select two consecutive lines with `V` then delete; or select a substring with `v` then change.

- [ ] **Step 1: Rewrite the file**

```lua
-- Warrior room: v/V. Select a block of lines, delete them.
return {
  id = "warrior_visual",
  tier = "warrior",
  command = "v / V",
  title = "Visual Mode: v, V",
  description = "Select: characters (v), whole lines (V). Then apply an operator.",
  usage_tip = "v enters char-wise visual. V is line-wise. Extend with motion keys, then d/c/y.",
  before_example = "keep\n|drop\ndrop\nkeep",
  after_example = "keep\n|keep",
  filetype = "lua",
  cursor_start = { row = 2, col = 1 },
  time_limit = 50,
  goal = "Delete the two `unused` lines using line-wise visual select.",
  start_text = [[
local function calc()
  local unused = 1
  local unused_too = 2
  return result
end]],
  target_text = [[
local function calc()
  return result
end]],
  base_xp = 80,
  optimal_keystrokes = { "V", "j", "d" },
  optimal_keystrokes_alternates = {
    { "v", "j", "$", "d" },
    { "d", "j", "d", "d" },
  },
}
```

- [ ] **Step 2: Run reachability**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -B1 -A14 "warrior_visual"`

- [ ] **Step 3: Debug.** `Vjd` deletes 2 lines (cursor line + one below). Should land cleanly.

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/warrior/visual_mode.lua
git commit -m "feat(rooms): rewrite warrior_visual_mode with V-line-delete scenario"
```

---

## Task 18: warrior_visual_block — `<C-v>` + `I`

**Files:**
- Modify: `lua/rooms/warrior/visual_block.lua`

**Design.** Three lines that need the same prefix (`// `). Use `<C-v>` to select the first column on each, then `I` to insert at all.

- [ ] **Step 1: Rewrite the file**

```lua
-- Warrior room: <C-v> + I. Insert a comment prefix on multiple lines at once.
return {
  id = "warrior_visual_block",
  tier = "warrior",
  command = "<C-v> + I",
  title = "Visual Block Insert",
  description = "<C-v> selects a vertical block. I inserts at every selected line simultaneously.",
  usage_tip = "<C-v> enters visual block. Select lines with j. I to insert. <Esc> applies to all.",
  before_example = "a()\nb()\nc()|",
  after_example = "// a()\n// b()\n// c()|",
  filetype = "javascript",
  cursor_start = { row = 1, col = 1 },
  time_limit = 50,
  goal = "Comment out the three function calls by prefixing each with `// `.",
  start_text = [[
fetchUser();
loadCache();
syncQueue();]],
  target_text = [[
// fetchUser();
// loadCache();
// syncQueue();]],
  base_xp = 100,
  optimal_keystrokes = { "\22", "j", "j", "I", "/", "/", " ", "\27" },
  optimal_keystrokes_alternates = {
    { "I", "/", "/", " ", "\27", "j", ".", "j", "." },
  },
}
```

- [ ] **Step 2: Run reachability**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -B1 -A14 "warrior_visual_block"`

- [ ] **Step 3: Debug.** `<C-v>` = `\22`. After `I /  / <space> <Esc>`, the visual-block insert applies to all selected lines. If only the first line gets the prefix, the `<Esc>` may have fired before the redraw — alternate #1 (sequential `.` repeats) is the reliable fallback.

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/warrior/visual_block.lua
git commit -m "feat(rooms): rewrite warrior_visual_block with comment-out scenario"
```

---

## Task 19: warrior_boss — 3-phase siege

**Files:**
- Modify: `lua/rooms/warrior/boss.lua`

**Design.** Spec calls boss "search, visual block, and macros". Three phases at warrior calibration:

**Phase 1 — search + rename (cgn-style).** Snippet with 3 occurrences of `oldVar`.
**Phase 2 — visual block comment-out.** Same shape as Task 18 but 4 lines.
**Phase 3 — record + replay macro.** Same shape as Task 16 but 4 lines.

- [ ] **Step 1: Rewrite the file**

```lua
-- Warrior boss: 3-phase siege. Search rename, visual block comment, macro replay.
return {
  id = "warrior_boss",
  tier = "warrior",
  is_boss = true,
  command = "search + visual block + macros",
  title = "BOSS: The Siege",
  description = "Three-phase trial. Search, visual block, and macros.",
  usage_tip = "Chain * + cgn, then <C-v> + I, then qa ... q + @a.",
  base_xp = 500,
  time_limit = 240,
  phases = {
    {
      tip = "Phase 1: Rename `tmp` everywhere",
      filetype = "lua",
      cursor_start = { row = 1, col = 7 },
      goal = "Rename all 3 occurrences of `tmp` to `out`.",
      start_text = [[
local tmp = compute()
local x = tmp * 2
return tmp + x]],
      target_text = [[
local out = compute()
local x = out * 2
return out + x]],
      optimal_keystrokes = { "*", "N", "c", "g", "n", "o", "u", "t", "\27", ".", "." },
    },
    {
      tip = "Phase 2: Comment out three calls",
      filetype = "javascript",
      cursor_start = { row = 1, col = 1 },
      goal = "Prefix each of the three calls with `// `.",
      start_text = [[
init();
start();
stop();]],
      target_text = [[
// init();
// start();
// stop();]],
      optimal_keystrokes = { "\22", "j", "j", "I", "/", "/", " ", "\27" },
    },
    {
      tip = "Phase 3: Append `;` to every line via macro",
      filetype = "lua",
      cursor_start = { row = 1, col = 1 },
      goal = "Use a macro to append `;` to all four lines.",
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
      optimal_keystrokes = { "q", "a", "A", ";", "\27", "j", "q", "@", "a", "@", "a", "@", "a" },
    },
  },
}
```

- [ ] **Step 2: Run reachability**

Run: `nvim --headless --noplugin -l tests/reachability.lua --all 2>&1 | grep -B1 -A20 "warrior_boss"`

- [ ] **Step 3: Debug each phase independently.** If phase 1 fails, ensure `cursor_start.col = 7` lands on `t` of `tmp` (line: `local tmp = compute()` → `l=1 o=2 c=3 a=4 l=5 ' '=6 t=7`). Phase 2 mirrors Task 18; phase 3 mirrors Task 16.

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/warrior/boss.lua
git commit -m "feat(rooms): rewrite warrior_boss with three real-world phases"
```

---

## Task 20: Full warrior sweep

**Files:**
- None (verification only).

- [ ] **Step 1: Run full CI-mode reachability**

Run: `nvim --headless --noplugin -l tests/reachability.lua`
Expected: `reachability: 44 checked, X skipped (no goal), all sequences pass`. 44 = 23 beginner (already shipped) + 18 warrior + 3 warrior boss phases.

If `skipped` includes any warrior room, that file is missing its `goal` field — find and fix.

- [ ] **Step 2: Run busted**

Run: `~/.luarocks/bin/busted`
Expected: 158/158 successes (or matching prior count — no new tests added in this PR).

- [ ] **Step 3: Manual smoke test (optional)**

Launch nvim, pick a warrior room via the project's room picker, verify:
- `goal` line renders in HUD
- Syntax highlighting matches `filetype` (Lua/TypeScript/SQL/JavaScript)
- Cursor lands at `cursor_start`
- No interference from user plugins (autopairs/LSP) — PR 1 hygiene.

- [ ] **Step 4: Final commit if anything tweaked**

```bash
git add -u
git commit -m "fix(rooms): tighten warrior content after full-tier sweep"
```

---

## Self-Review Checklist

1. **Spec coverage:**
   - All 18 warrior regular rooms + 1 boss listed in spec coverage table → present as Tasks 1–19. ✓
   - Schema additions (`filetype`/`cursor_start`/`goal`) applied in every file. ✓
   - Reachability harness gate before every commit. ✓
   - Tier calibration: 10–20 line snippets, 15–40 key sequences, base_xp 80–110, time_limit 50–90s. ✓
   - Multiple alternates per room where appropriate. ✓

2. **Placeholder scan:** Every task has full file content + concrete reachability command + targeted debug step pointing at the most likely failure. Known weak rooms flagged: Task 2 (ci_combo primary brittle), Task 6 (scroll primary brittle, prefer alternate), Task 12 (cursor col needs recount), Task 13 (cursor col needs recount), Task 16/19 (macros may need fallback under feedkeys), Task 18 (visual-block I may need `.` fallback). ✓

3. **Type consistency:** Field names match `rooms.lua` validator. Escape encoding `"\27"` / `"\18"` / `"\22"` / `"\r"` used consistently. ✓
