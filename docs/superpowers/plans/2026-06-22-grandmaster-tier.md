# Grandmaster Tier Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a fourth tier `grandmaster` (10 rooms + 3-phase boss) focused on ex-command and line-op mastery, unlocked after the ninja boss.

**Architecture:** Wire `grandmaster` into the 7 tier-enumeration points and add its highlight/unlock rule (Task 1). Add a small per-room `wo` (window-option) mechanism so the folds room can enable `foldmethod` (Task 2). Author the 10 rooms in batches gated by the reachability harness (Tasks 3-6), then the boss + docs (Task 7).

**Tech Stack:** Lua 5.1+, Neovim Lua API, busted, the reachability harness (`nvim --headless --noplugin -l tests/reachability.lua`).

## Global Constraints

- Tier name `grandmaster`: directory `lua/rooms/grandmaster/`, ids `grandmaster_*`, label `GRANDMASTER`.
- Unlock: `grandmaster` requires `ninja_boss` cleared.
- 9 text-ops rooms + 1 folds room + 1 boss; no splits/tabs/multi-file rooms (engine pins input to the play window / single buffer).
- Every text-ops room and every boss phase carries a `goal` (reachability-checked) and an `efficiency_hint`; the folds room has NO `goal` (exempt from the harness).
- Reachability is the correctness gate for authored keystrokes: run `nvim --headless --noplugin -l tests/reachability.lua`; if a sequence fails, fix the keystrokes/text until it passes.
- New highlight `VimmerTierGrandmaster` fg `#bd93f9`.
- Busted: `~/.luarocks/bin/busted tests/spec/`. Reachability: command above (exit 0 = pass).
- Commit messages use Conventional Commits.

---

### Task 1: Tier wiring + highlight + unlock

**Files:**
- Modify: `lua/the-vimmer/rooms.lua:8` (TIERS)
- Modify: `tests/reachability.lua:22` (TIERS)
- Modify: `lua/the-vimmer/progress.lua` (`is_tier_unlocked` ~152-155)
- Modify: `lua/the-vimmer/highlights.lua` (~93)
- Modify: `lua/the-vimmer/ui/map.lua` (~27-34)
- Modify: `lua/the-vimmer/ui/progress.lua` (~24-31)
- Modify: `lua/the-vimmer/ui/results.lua` (~130)
- Create: `lua/rooms/grandmaster/.gitkeep` (empty dir so `load_tier` works before rooms exist)
- Test: `tests/spec/progress_spec.lua`

**Interfaces:**
- Consumes: nothing new.
- Produces: `grandmaster` recognised by `all_tiers()`, `is_tier_unlocked`, map/progress UIs; `VimmerTierGrandmaster` highlight.

- [ ] **Step 1: Write the failing test**

Add to `tests/spec/progress_spec.lua`:

```lua
describe("progress.is_tier_unlocked grandmaster", function()
  it("is locked without ninja_boss", function()
    assert.is_false(progress.is_tier_unlocked("grandmaster", {}))
  end)

  it("unlocks once ninja_boss is cleared", function()
    assert.is_true(progress.is_tier_unlocked("grandmaster", { ninja_boss = true }))
  end)
end)

describe("rooms.all_tiers includes grandmaster", function()
  local rooms = require("the-vimmer.rooms")
  it("lists grandmaster last", function()
    local t = rooms.all_tiers()
    assert.equals("grandmaster", t[#t])
  end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `~/.luarocks/bin/busted tests/spec/progress_spec.lua`
Expected: FAIL — grandmaster unlock returns false even with `ninja_boss`, and `all_tiers()` last element is `"ninja"`.

- [ ] **Step 3: Implement the wiring**

`lua/the-vimmer/rooms.lua` line 8:

```lua
local TIERS = { "beginner", "warrior", "ninja", "grandmaster" }
```

`tests/reachability.lua` line ~22:

```lua
local TIERS = { "beginner", "warrior", "ninja", "grandmaster" }
```

`lua/the-vimmer/progress.lua` `is_tier_unlocked`:

```lua
function M.is_tier_unlocked(tier, cleared)
  if tier == "beginner" then return true end
  local boss_id =
    (tier == "warrior") and "beginner_boss"
    or (tier == "ninja") and "warrior_boss"
    or "ninja_boss"
  return cleared[boss_id] == true
end
```

`lua/the-vimmer/highlights.lua` after the `VimmerTierNinja` line:

```lua
  hl(0, "VimmerTierGrandmaster", { bold = true, fg = "#bd93f9" })
```

`lua/the-vimmer/ui/map.lua` — extend the four structures:

```lua
  local tier_colors = {
    beginner = "VimmerTierBeginner",
    warrior  = "VimmerTierWarrior",
    ninja    = "VimmerTierNinja",
    grandmaster = "VimmerTierGrandmaster",
  }
  local tier_labels = { beginner = "BEGINNER", warrior = "WARRIOR", ninja = "NINJA", grandmaster = "GRANDMASTER" }
  local tier_prereq = { warrior = "complete boss first", ninja = "complete boss first", grandmaster = "complete boss first" }
  local tiers = { "beginner", "warrior", "ninja", "grandmaster" }
```

`lua/the-vimmer/ui/progress.lua` — same four additions:

```lua
  local tiers = { "beginner", "warrior", "ninja", "grandmaster" }
  local tier_labels = { beginner = "BEGINNER", warrior = "WARRIOR", ninja = "NINJA", grandmaster = "GRANDMASTER" }
  local tier_colors = {
    beginner = "VimmerTierBeginner",
    warrior = "VimmerTierWarrior",
    ninja = "VimmerTierNinja",
    grandmaster = "VimmerTierGrandmaster",
  }
  local tier_prereq = { warrior = "beat beginner boss", ninja = "beat warrior boss", grandmaster = "beat ninja boss" }
```

`lua/the-vimmer/ui/results.lua` line ~130 — add grandmaster to the banner group map:

```lua
    local tier_grp = ({ warrior = "VimmerTierWarrior", ninja = "VimmerTierNinja", grandmaster = "VimmerTierGrandmaster" })[tier_name]
      or "VimmerTierBeginner"
```

Create the empty rooms dir:

```bash
mkdir -p lua/rooms/grandmaster && touch lua/rooms/grandmaster/.gitkeep
```

- [ ] **Step 4: Run tests + reachability + map smoke**

Run: `~/.luarocks/bin/busted tests/spec/`
Expected: PASS (existing + new specs).

Run: `nvim --headless --noplugin -l tests/reachability.lua; echo "exit=$?"`
Expected: `exit=0` (no grandmaster rooms yet; still passes).

Map smoke (save with ninja_boss cleared → GRANDMASTER section renders empty, no error):
```bash
T=$(mktemp -d); XDG_DATA_HOME="$T" nvim --headless --clean -u NORC -c "set rtp+=$(pwd)" \
  -c "lua require('the-vimmer').setup({})" \
  -c "lua local p=require('the-vimmer.progress'); local d=p.load(); d.cleared.ninja_boss=true; p.save(d)" \
  -c "lua local ok=pcall(function() require('the-vimmer.ui').open_map(require('the-vimmer.progress').load(), { beginner={}, warrior={}, ninja={}, grandmaster={} }, function() end) end); print('map ok', ok)" \
  -c "qa!" 2>&1 | tail -1; rm -rf "$T"
```
Expected: `map ok  true`.

- [ ] **Step 5: Commit**

```bash
git add lua/the-vimmer/rooms.lua tests/reachability.lua lua/the-vimmer/progress.lua lua/the-vimmer/highlights.lua lua/the-vimmer/ui/map.lua lua/the-vimmer/ui/progress.lua lua/the-vimmer/ui/results.lua lua/rooms/grandmaster/.gitkeep tests/spec/progress_spec.lua
git commit -m "feat(grandmaster): wire fourth tier (no rooms yet)"
```

---

### Task 2: Per-room `wo` (window-option) support

**Files:**
- Modify: `lua/the-vimmer/rooms.lua` (`phase_view` ~95-106)
- Modify: `lua/the-vimmer/ui/play.lua` (`start_phase` bo-application block ~256-261)
- Test: `tests/spec/rooms_spec.lua`

**Interfaces:**
- Consumes: nothing.
- Produces: `phase_view(ctx).wo` surfaced (nil when unset); `play.lua` applies a `wo` table to the play window via `vim.wo[play_win][k] = v`. Needed by the folds room (Task 6) to set `foldmethod` (a window-local option `bo` cannot set).

- [ ] **Step 1: Write the failing test**

Add to `tests/spec/rooms_spec.lua`:

```lua
describe("rooms.phase_view wo", function()
  it("surfaces a wo table", function()
    local v = rooms.phase_view({ wo = { foldmethod = "indent" } })
    assert.same({ foldmethod = "indent" }, v.wo)
  end)

  it("leaves wo nil when unset", function()
    assert.is_nil(rooms.phase_view({}).wo)
  end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `~/.luarocks/bin/busted tests/spec/rooms_spec.lua`
Expected: FAIL — `wo` is nil for the first case.

- [ ] **Step 3: Implement**

In `lua/the-vimmer/rooms.lua` `M.phase_view`, add to the returned table:

```lua
    bo = ctx.bo,
    wo = ctx.wo,
```

(The `bo = ctx.bo` line already exists; add the `wo` line directly after it.)

In `lua/the-vimmer/ui/play.lua`, in `start_phase`, after the existing `bo`
application block:

```lua
    local bo = view.bo or room.bo
    if type(bo) == "table" then
      for k, v in pairs(bo) do
        vim.bo[play_buf][k] = v
      end
    end
```

add:

```lua
    local wo = view.wo or room.wo
    if type(wo) == "table" then
      for k, v in pairs(wo) do
        vim.wo[play_win][k] = v
      end
    end
```

- [ ] **Step 4: Run tests**

Run: `~/.luarocks/bin/busted tests/spec/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lua/the-vimmer/rooms.lua lua/the-vimmer/ui/play.lua tests/spec/rooms_spec.lua
git commit -m "feat(play): support per-room window options (wo)"
```

---

### Task 3: Rooms 1-3 (substitute captures, &, :g/normal)

**Files:**
- Create: `lua/rooms/grandmaster/sub_captures.lua`, `sub_amp.lua`, `global_normal.lua`
- Test: reachability harness.

**Interfaces:**
- Consumes: room schema (existing); reachability harness checks `goal` rooms.
- Produces: 3 grandmaster rooms.

- [ ] **Step 1: Create `lua/rooms/grandmaster/sub_captures.lua`**

```lua
-- Grandmaster: swap two words on each line with capture groups.
return {
  id = "grandmaster_sub_captures",
  tier = "grandmaster",
  command = ":s/\\(\\w\\+\\) \\(\\w\\+\\)/\\2 \\1/",
  title = "Substitute: Capture Groups",
  description = "Reorder text by capturing pieces with \\( \\) and replaying them as \\1 \\2.",
  before_example = "alpha beta",
  after_example = "beta alpha",
  usage_tip = "Capture with \\( \\), reference captures as \\1, \\2 in the replacement.",
  efficiency_hint = "One :%s with \\(\\) capture groups swaps both lines at once.",
  filetype = "text",
  cursor_start = { row = 1, col = 1 },
  goal = "Swap the two words on every line using capture groups.",
  start_text = [[
alpha beta
gamma delta]],
  target_text = [[
beta alpha
delta gamma]],
  base_xp = 90,
  time_limit = 75,
  optimal_keystrokes = {
    ":", "%", "s", "/", "\\", "(", "\\", "w", "\\", "+", "\\", ")", " ",
    "\\", "(", "\\", "w", "\\", "+", "\\", ")", "/", "\\", "2", " ", "\\", "1", "/", "\r",
  },
}
```

- [ ] **Step 2: Create `lua/rooms/grandmaster/sub_amp.lua`**

```lua
-- Grandmaster: wrap every number using & (the whole match) in the replacement.
return {
  id = "grandmaster_sub_amp",
  tier = "grandmaster",
  command = ":%s/\\d\\+/[&]/g",
  title = "Substitute: Whole-Match &",
  description = "& in the replacement stands for the entire matched text.",
  before_example = "x = 10",
  after_example = "x = [10]",
  usage_tip = "Use & (or \\0) to reuse the whole match without a capture group.",
  efficiency_hint = "& reuses the whole match — no capture group needed to wrap it.",
  filetype = "text",
  cursor_start = { row = 1, col = 1 },
  goal = "Wrap every number in square brackets using &.",
  start_text = [[
x = 10
y = 250]],
  target_text = [[
x = [10]
y = [250]]],
  base_xp = 90,
  time_limit = 75,
  optimal_keystrokes = {
    ":", "%", "s", "/", "\\", "d", "\\", "+", "/", "[", "&", "]", "/", "g", "\r",
  },
}
```

- [ ] **Step 3: Create `lua/rooms/grandmaster/global_normal.lua`**

```lua
-- Grandmaster: run a normal-mode edit on every matching line with :g//normal.
return {
  id = "grandmaster_global_normal",
  tier = "grandmaster",
  command = ":g/TODO/normal A!",
  title = "Global + Normal",
  description = ":g/pat/normal <keys> runs normal-mode keys on every matching line.",
  before_example = "TODO fix",
  after_example = "TODO fix!",
  usage_tip = "Combine :g with :normal to batch the same edit across matches.",
  efficiency_hint = ":g/TODO/normal A! appends to every matching line in one command.",
  filetype = "text",
  cursor_start = { row = 1, col = 1 },
  goal = "Append ! to every line containing TODO using :g + normal.",
  start_text = [[
keep this
TODO fix
keep that
TODO test]],
  target_text = [[
keep this
TODO fix!
keep that
TODO test!]],
  base_xp = 95,
  time_limit = 80,
  optimal_keystrokes = {
    ":", "g", "/", "T", "O", "D", "O", "/", "n", "o", "r", "m", "a", "l", " ", "A", "!", "\r",
  },
}
```

- [ ] **Step 4: Run reachability**

Run: `nvim --headless --noplugin -l tests/reachability.lua; echo "exit=$?"`
Expected: `exit=0`, output line `reachability: ... all sequences pass`. If any
grandmaster sequence fails, the harness prints the room id, its produced text,
and the expected text — fix the `optimal_keystrokes` or `start_text`/`target_text`
for that room until it passes.

- [ ] **Step 5: Commit**

```bash
git add lua/rooms/grandmaster/sub_captures.lua lua/rooms/grandmaster/sub_amp.lua lua/rooms/grandmaster/global_normal.lua
git commit -m "feat(grandmaster): add substitute-captures, &, global-normal rooms"
```

---

### Task 4: Rooms 4-6 (:g move, :t copy, :m move)

**Files:**
- Create: `lua/rooms/grandmaster/global_move.lua`, `copy_line.lua`, `move_line.lua`
- Test: reachability harness.

- [ ] **Step 1: Create `lua/rooms/grandmaster/global_move.lua`**

```lua
-- Grandmaster: relocate every matching line to the end with :g//m$.
return {
  id = "grandmaster_global_move",
  tier = "grandmaster",
  command = ":g/^#/m$",
  title = "Global + Move",
  description = ":g/pat/m$ moves each matching line to the bottom, preserving order.",
  before_example = "# note (moves down)",
  after_example = "code (stays up)",
  usage_tip = "Pair :g with :m (or :t) to relocate or duplicate matching lines.",
  efficiency_hint = ":g/^#/m$ sweeps all comment lines to the end in one pass.",
  filetype = "text",
  cursor_start = { row = 1, col = 1 },
  goal = "Move every line starting with # to the end, keeping their order.",
  start_text = [[
# header one
code a
# header two
code b]],
  target_text = [[
code a
code b
# header one
# header two]],
  base_xp = 95,
  time_limit = 80,
  optimal_keystrokes = {
    ":", "g", "/", "^", "#", "/", "m", "$", "\r",
  },
}
```

- [ ] **Step 2: Create `lua/rooms/grandmaster/copy_line.lua`**

```lua
-- Grandmaster: duplicate a line with :t (copy to address).
return {
  id = "grandmaster_copy_line",
  tier = "grandmaster",
  command = ":1t$",
  title = "Copy Lines: :t",
  description = ":<range>t<addr> copies lines to after <addr>. :1t$ duplicates line 1 to the end.",
  before_example = "header / body",
  after_example = "header / body / header",
  usage_tip = ":t (alias :copy) duplicates lines anywhere by address.",
  efficiency_hint = ":1t$ copies the first line to the end in one command.",
  filetype = "text",
  cursor_start = { row = 1, col = 1 },
  goal = "Copy the first line to the end of the buffer with :t.",
  start_text = [[
header
body]],
  target_text = [[
header
body
header]],
  base_xp = 90,
  time_limit = 70,
  optimal_keystrokes = { ":", "1", "t", "$", "\r" },
}
```

- [ ] **Step 3: Create `lua/rooms/grandmaster/move_line.lua`**

```lua
-- Grandmaster: relocate a line with :m (move to address).
return {
  id = "grandmaster_move_line",
  tier = "grandmaster",
  command = ":3m0",
  title = "Move Lines: :m",
  description = ":<range>m<addr> moves lines to after <addr>. :3m0 moves line 3 to the top.",
  before_example = "second / third / first",
  after_example = "first / second / third",
  usage_tip = ":m (alias :move) relocates lines by address; 0 means before line 1.",
  efficiency_hint = ":3m0 lifts the third line to the top in one command.",
  filetype = "text",
  cursor_start = { row = 1, col = 1 },
  goal = "Move the third line to the top with :m.",
  start_text = [[
second
third
first]],
  target_text = [[
first
second
third]],
  base_xp = 90,
  time_limit = 70,
  optimal_keystrokes = { ":", "3", "m", "0", "\r" },
}
```

- [ ] **Step 4: Run reachability**

Run: `nvim --headless --noplugin -l tests/reachability.lua; echo "exit=$?"`
Expected: `exit=0`, all sequences pass. Fix any failing room as in Task 3 Step 4.

- [ ] **Step 5: Commit**

```bash
git add lua/rooms/grandmaster/global_move.lua lua/rooms/grandmaster/copy_line.lua lua/rooms/grandmaster/move_line.lua
git commit -m "feat(grandmaster): add global-move, :t copy, :m move rooms"
```

---

### Task 5: Rooms 7-9 (filter, range :normal, & repeat)

**Files:**
- Create: `lua/rooms/grandmaster/filter.lua`, `norm_range.lua`, `amp_repeat.lua`
- Test: reachability harness.

- [ ] **Step 1: Create `lua/rooms/grandmaster/filter.lua`**

```lua
-- Grandmaster: filter the whole buffer through an external command with :%!.
return {
  id = "grandmaster_filter",
  tier = "grandmaster",
  command = ":%!sort",
  title = "External Filter: :!",
  description = ":<range>!cmd pipes lines through a shell command and replaces them with its output.",
  before_example = "charlie / alpha / bravo",
  after_example = "alpha / bravo / charlie",
  usage_tip = ":%!sort, :%!uniq, :%!column — pipe the buffer through any filter.",
  efficiency_hint = ":%!sort filters the whole buffer through sort in one command.",
  filetype = "text",
  cursor_start = { row = 1, col = 1 },
  goal = "Sort all lines by piping the buffer through sort.",
  start_text = [[
charlie
alpha
bravo]],
  target_text = [[
alpha
bravo
charlie]],
  base_xp = 95,
  time_limit = 80,
  optimal_keystrokes = { ":", "%", "!", "s", "o", "r", "t", "\r" },
}
```

Note: this room relies on the external `sort`. If the reachability harness
cannot run `sort` in the target environment (rare), remove the `goal` line to
exempt it from the harness (it then stays budget-only); record that you did so.

- [ ] **Step 2: Create `lua/rooms/grandmaster/norm_range.lua`**

```lua
-- Grandmaster: apply normal-mode keys to a line range with :%norm.
return {
  id = "grandmaster_norm_range",
  tier = "grandmaster",
  command = ":%norm $x",
  title = "Range :normal",
  description = ":<range>norm <keys> runs the same normal-mode keys on each line in the range.",
  before_example = "alpha,",
  after_example = "alpha",
  usage_tip = ":%norm runs any normal command (here $x deletes the last char) per line.",
  efficiency_hint = ":%norm $x strips the trailing char from every line at once.",
  filetype = "text",
  cursor_start = { row = 1, col = 1 },
  goal = "Delete the trailing comma from every line using :%norm.",
  start_text = [[
alpha,
beta,
gamma,]],
  target_text = [[
alpha
beta
gamma]],
  base_xp = 95,
  time_limit = 80,
  optimal_keystrokes = { ":", "%", "n", "o", "r", "m", " ", "$", "x", "\r" },
}
```

- [ ] **Step 3: Create `lua/rooms/grandmaster/amp_repeat.lua`**

```lua
-- Grandmaster: repeat the last :substitute on another line with &.
return {
  id = "grandmaster_amp_repeat",
  tier = "grandmaster",
  command = ":s/old/new/ then &",
  title = "Repeat Substitute: &",
  description = "& repeats the last :s on the current line. Substitute once, then & elsewhere.",
  before_example = "foo here",
  after_example = "bar here",
  usage_tip = "Run :s once, move to the next line, press & to replay it.",
  efficiency_hint = "Run :s once, then & on the next line repeats it without retyping.",
  filetype = "text",
  cursor_start = { row = 1, col = 1 },
  goal = "Replace foo with bar on both lines: :s once, then & on the next.",
  start_text = [[
foo here
foo there]],
  target_text = [[
bar here
bar there]],
  base_xp = 90,
  time_limit = 75,
  optimal_keystrokes = {
    ":", "s", "/", "f", "o", "o", "/", "b", "a", "r", "/", "\r", "j", "&",
  },
}
```

- [ ] **Step 4: Run reachability**

Run: `nvim --headless --noplugin -l tests/reachability.lua; echo "exit=$?"`
Expected: `exit=0`, all sequences pass. Fix any failing room as in Task 3 Step 4.
If `filter` fails specifically due to a missing `sort`, apply the exemption note
in Step 1.

- [ ] **Step 5: Commit**

```bash
git add lua/rooms/grandmaster/filter.lua lua/rooms/grandmaster/norm_range.lua lua/rooms/grandmaster/amp_repeat.lua
git commit -m "feat(grandmaster): add :%! filter, range :norm, & repeat rooms"
```

---

### Task 6: Room 10 — folds (nav, uses `wo`, no goal)

**Files:**
- Create: `lua/rooms/grandmaster/folds.lua`
- Test: reachability harness (skips this room) + headless solve smoke.

**Interfaces:**
- Consumes: the `wo` mechanism (Task 2) to set `foldmethod`.

- [ ] **Step 1: Create `lua/rooms/grandmaster/folds.lua`**

```lua
-- Grandmaster (nav): open a fold, then edit. foldmethod=indent via wo.
-- No `goal`: folds don't change text, so the reachability harness skips it.
return {
  id = "grandmaster_folds",
  tier = "grandmaster",
  command = "zR / za / zj",
  title = "Folds: Navigate & Edit",
  description = "Indent folds collapse blocks. zR opens all, za toggles one, zj jumps to the next fold.",
  before_example = "config = { ... }  (folded)",
  after_example = "timeout = 9  (opened & edited)",
  usage_tip = "zR opens every fold, zM closes them, za toggles the fold under the cursor.",
  efficiency_hint = "zR opens all folds at once instead of toggling each with za.",
  filetype = "lua",
  cursor_start = { row = 1, col = 1 },
  wo = { foldmethod = "indent", foldenable = true, foldlevel = 0 },
  start_text = [[
config = {
    timeout = 5
}]],
  target_text = [[
config = {
    timeout = 9
}]],
  base_xp = 85,
  time_limit = 75,
  optimal_keystrokes = { "z", "R", "j", "$", "r", "9" },
}
```

- [ ] **Step 2: Run reachability (confirms it is skipped, no regressions)**

Run: `nvim --headless --noplugin -l tests/reachability.lua; echo "exit=$?"`
Expected: `exit=0`. The folds room has no `goal`, so the harness reports it as
skipped (counted in "skipped (no goal)") and all goal rooms still pass.

- [ ] **Step 3: Headless solve smoke (the optimal keys reach the target)**

```bash
nvim --headless --clean -u NORC -c "set rtp+=$(pwd)" \
  -c "lua
    local b=vim.api.nvim_create_buf(false,true)
    vim.api.nvim_buf_set_lines(b,0,-1,false,{'config = {','    timeout = 5','}'})
    vim.api.nvim_set_current_buf(b)
    vim.bo[b].expandtab=true
    vim.wo.foldmethod='indent'; vim.wo.foldenable=true; vim.wo.foldlevel=0
    vim.api.nvim_win_set_cursor(0,{1,0})
    vim.api.nvim_feedkeys('zRj\$r9','x',false)
    print('result', table.concat(vim.api.nvim_buf_get_lines(b,0,-1,false),'|'))" \
  -c "qa!" 2>&1 | tail -1
```
Expected: `result config = {|    timeout = 9|}` (the `5` became `9`). If the
keystrokes do not reach it, adjust `optimal_keystrokes`.

- [ ] **Step 4: Commit**

```bash
git add lua/rooms/grandmaster/folds.lua
git commit -m "feat(grandmaster): add folds navigate-and-edit room"
```

---

### Task 7: Boss + room-count assertion + README

**Files:**
- Create: `lua/rooms/grandmaster/boss.lua`
- Modify: `README.md` (Rooms tier table; room counts)
- Test: `tests/spec/rooms_spec.lua` + reachability.

**Interfaces:**
- Consumes: boss schema (mirrors `lua/rooms/ninja/boss.lua`).
- Produces: `grandmaster_boss`; `load_tier("grandmaster")` returns 11 entries (10 rooms + boss).

- [ ] **Step 1: Create `lua/rooms/grandmaster/boss.lua`**

```lua
-- Grandmaster boss: 3-phase trial. Capture-sub, global-normal, copy/move reshape.
return {
  id = "grandmaster_boss",
  tier = "grandmaster",
  is_boss = true,
  command = "captures + :g/normal + :t/:m",
  title = "BOSS: The Ex Machina",
  description = "Three-phase trial of ex-command mastery: captures, global edits, line surgery.",
  usage_tip = "Reformat with capture groups, batch-edit with :g/normal, reshape with :m and :t.",
  base_xp = 950,
  time_limit = 360,
  phases = {
    {
      tip = "Phase 1: Reformat 'Last, First' into 'First Last' on every line",
      filetype = "text",
      cursor_start = { row = 1, col = 1 },
      goal = "Turn 'Last, First' into 'First Last' on every line with capture groups.",
      start_text = [[
Smith, John
Doe, Jane]],
      target_text = [[
John Smith
Jane Doe]],
      optimal_keystrokes = {
        ":", "%", "s", "/", "\\", "(", "\\", "w", "\\", "+", "\\", ")", ",", " ",
        "\\", "(", "\\", "w", "\\", "+", "\\", ")", "/", "\\", "2", " ", "\\", "1", "/", "\r",
      },
    },
    {
      tip = "Phase 2: Append '();' to every line beginning with fn",
      filetype = "text",
      cursor_start = { row = 1, col = 1 },
      goal = "Append '();' to each line starting with fn using :g + normal.",
      start_text = [[
keep
fn alpha
fn beta]],
      target_text = [[
keep
fn alpha();
fn beta();]],
      optimal_keystrokes = {
        ":", "g", "/", "^", "f", "n", "/", "n", "o", "r", "m", "a", "l", " ",
        "A", "(", ")", ";", "\r",
      },
    },
    {
      tip = "Phase 3: Move line 2 to the top, then copy the new top line to the end",
      filetype = "text",
      cursor_start = { row = 1, col = 1 },
      goal = "Move line 2 to the top with :m, then copy the top line to the end with :t.",
      start_text = [[
mid
top]],
      target_text = [[
top
mid
top]],
      optimal_keystrokes = {
        ":", "2", "m", "0", "\r", ":", "1", "t", "$", "\r",
      },
    },
  },
}
```

- [ ] **Step 2: Write the room-count test**

Add to `tests/spec/rooms_spec.lua`:

```lua
describe("rooms.load_tier grandmaster", function()
  it("loads 10 rooms plus the boss and all validate", function()
    local list = rooms.load_tier("grandmaster")
    assert.equals(11, #list)
    local bosses, hinted = 0, 0
    for _, r in ipairs(list) do
      assert.is_true(rooms.validate(r))
      if r.is_boss then bosses = bosses + 1
      elseif r.efficiency_hint then hinted = hinted + 1 end
    end
    assert.equals(1, bosses)
    assert.equals(10, hinted)  -- every regular room has an efficiency_hint
  end)
end)
```

- [ ] **Step 3: Run reachability + full suite**

Run: `nvim --headless --noplugin -l tests/reachability.lua; echo "exit=$?"`
Expected: `exit=0`, all sequences pass (incl. the 3 boss phases).

Run: `~/.luarocks/bin/busted tests/spec/`
Expected: PASS — including the new 11-room assertion.

- [ ] **Step 4: Update README**

In `README.md`, in the Rooms table, add a Grandmaster row:

```markdown
| Grandmaster | substitute captures, & whole-match, :g/normal, :g/move, :t copy, :m move, :%! filter, range :norm, & repeat, folds |
```

And update the tier-progression sentence to mention the grandmaster tier
unlocking after the ninja boss (find the existing "Beating a tier's boss
unlocks the next tier" paragraph and append grandmaster to the chain).

- [ ] **Step 5: Commit**

```bash
git add lua/rooms/grandmaster/boss.lua tests/spec/rooms_spec.lua README.md
git commit -m "feat(grandmaster): add boss, room-count test, README"
```

---

## Self-Review

**Spec coverage:**
- Tier wiring 7 points + highlight + unlock (spec Part A) → Task 1. ✓
- `wo` window-option support for folds (spec edge case: foldmethod is window-local) → Task 2. ✓
- 9 text-ops rooms (spec Part B roster) → Tasks 3-5 (3+3+3). ✓
- Folds room, no goal, `wo` foldmethod (spec Part B #10) → Task 6. ✓
- 3-phase boss (spec Part C) → Task 7. ✓
- README + counts (spec Files touched) → Task 7 Step 4. ✓
- Reachability for all goal rooms/phases (spec Testing) → reachability run in Tasks 3-7. ✓
- Unlock + room-count specs (spec Testing) → Task 1 + Task 7 tests. ✓
- Filter external-`sort` risk (spec edge case) → Task 5 Step 1 note + Step 4 fallback. ✓

**Placeholder scan:** No TBD/TODO; every room file is complete; every command
has expected output. The "fix keystrokes if reachability fails" instruction is a
concrete TDD loop against an exact harness, not a vague placeholder.

**Type consistency:** Tier name `grandmaster` and label `GRANDMASTER` used
identically across Tasks 1-7; ids all `grandmaster_*`; `wo` table shape
(`{ foldmethod=..., foldenable=..., foldlevel=... }`) produced by Task 6 matches
what Task 2 applies (`vim.wo[play_win][k] = v`); `VimmerTierGrandmaster`
highlight defined in Task 1 and referenced in map/progress/results enumerations
in Task 1. Room count 11 (10 + boss) asserted in Task 7 matches 9 (Tasks 3-5) +
1 folds (Task 6) + 1 boss (Task 7). ✓
