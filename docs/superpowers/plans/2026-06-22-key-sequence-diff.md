# Key-Sequence Diff Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show the player's actual keys beside the most efficient accepted path, with a delta count and optional hint, on the results screen.

**Architecture:** Passive, post-run only. `game.lua` logs raw keys during play. Two pure helpers in `ui/common.lua` (`expand_keys`, `pick_baseline`) turn token sequences into comparable single-key counts and pick the shortest accepted path. `rooms.lua` gains an optional `efficiency_hint` field. `commands.lua` plumbs the data into the existing `run_stats` table; `results.lua` renders a side-by-side comparison block. No gameplay mechanics change.

**Tech Stack:** Lua 5.1+, Neovim Lua API, busted test framework.

## Global Constraints

- Pure helpers (`expand_keys`, `pick_baseline`, `format_key`) must run headlessly — no `vim.o`, `vim.api`, or Neovim-only globals. Plain Lua + the existing `tests/spec/helpers.lua` stub only.
- No gameplay rebalancing: HP, budget, win conditions, XP formula unchanged.
- No new user commands, no save-format/schema migration.
- `efficiency_hint` is an **optional** room/phase field — never required; existing 60 room files stay untouched.
- Comparison block renders only when `#keystroke_log > 0` AND a baseline exists; otherwise fall back to the existing optimal-only block (no regression).
- Run tests with: `~/.luarocks/bin/busted tests/spec/` (single file: append the path).
- Commit messages use Conventional Commits.

---

### Task 1: Log raw keystrokes in game state

**Files:**
- Modify: `lua/the-vimmer/game.lua` (state table in `M.new` ~lines 11-35; `register_key` ~105-113; `begin_play` ~83-101; `advance_boss_phase` ~165-168)
- Test: `tests/spec/game_spec.lua`

**Interfaces:**
- Consumes: nothing.
- Produces: `g.keystroke_log` (array of raw key strings, in press order); `g:keystroke_log_keys()` returns that array. Reset to `{}` on `begin_play` and `advance_boss_phase`. Capped at 300 entries.

- [ ] **Step 1: Write the failing test**

Add to `tests/spec/game_spec.lua` (after the existing `describe("game keystroke budget", ...)` block):

```lua
describe("game keystroke log", function()
  local g
  before_each(function()
    g = game.new()
    g:start_room(make_room())  -- optimal {"w","b"}
    g:begin_play()
  end)

  it("starts empty after begin_play", function()
    assert.same({}, g:keystroke_log_keys())
  end)

  it("appends each registered key in order", function()
    g:register_key("w")
    g:register_key("\27")  -- <Esc> raw byte
    assert.same({ "w", "\27" }, g:keystroke_log_keys())
  end)

  it("logs keys even when over budget", function()
    for _ = 1, 5 do g:register_key("x") end  -- budget is 3
    assert.equals(5, #g:keystroke_log_keys())
  end)

  it("resets on a fresh begin_play", function()
    g:register_key("w")
    g:begin_play()
    assert.same({}, g:keystroke_log_keys())
  end)

  it("caps the log at 300 entries", function()
    for _ = 1, 350 do g:register_key("x") end
    assert.equals(300, #g:keystroke_log_keys())
  end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `~/.luarocks/bin/busted tests/spec/game_spec.lua`
Expected: FAIL — `attempt to call method 'keystroke_log_keys' (a nil value)`.

- [ ] **Step 3: Write minimal implementation**

In `lua/the-vimmer/game.lua`, add to the state table in `M.new` (alongside the other keystroke fields, ~line 21):

```lua
    keystroke_log = {},          -- raw keys pressed this phase (capped at 300)
```

In `register_key`, append the key as the first action inside the function body, after the two early-return guards (so guarded calls in non-playing state are not logged), before `keystrokes_used` is incremented:

```lua
  function g:register_key(_key)
    if self.state ~= "playing" then return end
    if not self.current_room then return end
    if #self.keystroke_log < 300 then
      self.keystroke_log[#self.keystroke_log + 1] = _key
    end
    self.keystrokes_used = self.keystrokes_used + 1
```

In `begin_play`, reset the log near the other resets (e.g. right after `self.keystrokes_over_budget = 0`):

```lua
    self.keystroke_log = {}
```

In `advance_boss_phase`, reset the log alongside the per-phase budget reset:

```lua
  function g:advance_boss_phase()
    self.boss_phase = self.boss_phase + 1
    self.keystroke_log = {}
    self:_reset_keystroke_budget()
  end
```

Add the accessor near the other `g:` methods (e.g. after `is_dead`):

```lua
  function g:keystroke_log_keys()
    return self.keystroke_log
  end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `~/.luarocks/bin/busted tests/spec/game_spec.lua`
Expected: PASS — all game specs green (existing + 5 new).

- [ ] **Step 5: Commit**

```bash
git add lua/the-vimmer/game.lua tests/spec/game_spec.lua
git commit -m "feat(game): log raw keystrokes per phase"
```

---

### Task 2: `expand_keys` helper

**Files:**
- Modify: `lua/the-vimmer/ui/common.lua`
- Test: `tests/spec/ui_common_spec.lua`

**Interfaces:**
- Consumes: nothing.
- Produces: `common.expand_keys(tokens)` — takes an array of token strings, returns a flat array of single keys. A `<...>` chunk counts as one key; every other character counts as one key. Pure, no Neovim deps.

- [ ] **Step 1: Write the failing test**

Add to `tests/spec/ui_common_spec.lua`:

```lua
describe("ui.common.expand_keys", function()
  it("splits a multi-char token into single keys", function()
    assert.same({ "c", "i", "w" }, c.expand_keys({ "ciw" }))
  end)

  it("keeps <...> notation as one key", function()
    assert.same({ "<Esc>" }, c.expand_keys({ "<Esc>" }))
  end)

  it("expands a mixed sequence", function()
    assert.same({ "j", "$", "r", "5" }, c.expand_keys({ "j", "$", "r", "5" }))
  end)

  it("handles a token with text and a notation key", function()
    assert.same({ "c", "i", "w", "x", "<Esc>" },
      c.expand_keys({ "ciw", "x", "<Esc>" }))
  end)

  it("returns empty for empty input", function()
    assert.same({}, c.expand_keys({}))
    assert.same({}, c.expand_keys(nil))
  end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `~/.luarocks/bin/busted tests/spec/ui_common_spec.lua`
Expected: FAIL — `attempt to call field 'expand_keys' (a nil value)`.

- [ ] **Step 3: Write minimal implementation**

Add to `lua/the-vimmer/ui/common.lua` (after `format_key`):

```lua
-- Expand a list of optimal-keystroke tokens into single keys so they can be
-- counted against the player's raw key log. A `<...>` chunk (e.g. "<Esc>")
-- counts as one key; every other character counts as one key.
-- "ciw" -> {"c","i","w"}; "<Esc>" -> {"<Esc>"}.
function M.expand_keys(tokens)
  local out = {}
  for _, tok in ipairs(tokens or {}) do
    local i, n = 1, #tok
    while i <= n do
      if tok:sub(i, i) == "<" then
        local close = tok:find(">", i, true)
        if close then
          out[#out + 1] = tok:sub(i, close)
          i = close + 1
        else
          out[#out + 1] = tok:sub(i, i)
          i = i + 1
        end
      else
        out[#out + 1] = tok:sub(i, i)
        i = i + 1
      end
    end
  end
  return out
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `~/.luarocks/bin/busted tests/spec/ui_common_spec.lua`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lua/the-vimmer/ui/common.lua tests/spec/ui_common_spec.lua
git commit -m "feat(common): add expand_keys token expander"
```

---

### Task 3: `pick_baseline` helper

**Files:**
- Modify: `lua/the-vimmer/ui/common.lua`
- Test: `tests/spec/ui_common_spec.lua`

**Interfaces:**
- Consumes: `common.expand_keys` (Task 2); `rooms.acceptable_key_sequences(ctx)` (existing in `lua/the-vimmer/rooms.lua`, returns `{primary, alt1, ...}` token-list array).
- Produces: `common.pick_baseline(ctx)` — returns `{ tokens = <token list>, expanded_count = <int> }` for the accepted sequence with the fewest expanded keys (primary wins ties), or `nil` when no sequence exists.

- [ ] **Step 1: Write the failing test**

Add to `tests/spec/ui_common_spec.lua`:

```lua
describe("ui.common.pick_baseline", function()
  it("returns the single path when there are no alternates", function()
    local ctx = { optimal_keystrokes = { "j", "$", "r", "5" } }
    local b = c.pick_baseline(ctx)
    assert.same({ "j", "$", "r", "5" }, b.tokens)
    assert.equals(4, b.expanded_count)
  end)

  it("picks the alternate with fewest expanded keys", function()
    local ctx = {
      optimal_keystrokes = { "j", "l", "l", "l", "r", "5" },  -- 6
      optimal_keystrokes_alternates = { { "j", "$", "r", "5" } },  -- 4
    }
    local b = c.pick_baseline(ctx)
    assert.same({ "j", "$", "r", "5" }, b.tokens)
    assert.equals(4, b.expanded_count)
  end)

  it("counts multi-char tokens by expanded length", function()
    local ctx = { optimal_keystrokes = { "ciw", "x", "<Esc>" } }  -- 3+1+1 = 5
    local b = c.pick_baseline(ctx)
    assert.equals(5, b.expanded_count)
  end)

  it("breaks ties in favor of the primary", function()
    local ctx = {
      optimal_keystrokes = { "a", "b" },
      optimal_keystrokes_alternates = { { "c", "d" } },
    }
    assert.same({ "a", "b" }, c.pick_baseline(ctx).tokens)
  end)

  it("returns nil when there is no sequence", function()
    assert.is_nil(c.pick_baseline({}))
  end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `~/.luarocks/bin/busted tests/spec/ui_common_spec.lua`
Expected: FAIL — `attempt to call field 'pick_baseline' (a nil value)`.

- [ ] **Step 3: Write minimal implementation**

Add to `lua/the-vimmer/ui/common.lua` (after `expand_keys`):

```lua
-- Choose the accepted key sequence with the fewest expanded keystrokes (the
-- most efficient path) for a room or boss-phase context. Returns
-- { tokens = <token list>, expanded_count = <int> } or nil if none exist.
-- Ties resolve to the first sequence (primary path).
function M.pick_baseline(ctx)
  local seqs = require("the-vimmer.rooms").acceptable_key_sequences(ctx)
  local best_tokens, best_count = nil, nil
  for _, seq in ipairs(seqs) do
    local count = #M.expand_keys(seq)
    if best_count == nil or count < best_count then
      best_tokens, best_count = seq, count
    end
  end
  if not best_tokens then return nil end
  return { tokens = best_tokens, expanded_count = best_count }
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `~/.luarocks/bin/busted tests/spec/ui_common_spec.lua`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lua/the-vimmer/ui/common.lua tests/spec/ui_common_spec.lua
git commit -m "feat(common): add pick_baseline for efficient-path selection"
```

---

### Task 4: Optional `efficiency_hint` schema field

**Files:**
- Modify: `lua/the-vimmer/rooms.lua` (`validate_optional_additions` ~61-66; `phase_view` ~95-106)
- Test: `tests/spec/rooms_spec.lua`

**Interfaces:**
- Consumes: nothing.
- Produces: `efficiency_hint` accepted as optional (`nil` or string) by `rooms.validate`; surfaced by `rooms.phase_view(ctx)` as `view.efficiency_hint`.

- [ ] **Step 1: Write the failing test**

Add to `tests/spec/rooms_spec.lua` (reuse the file's `valid_room` table inside a new describe block; redeclare a local copy so the block is self-contained):

```lua
describe("rooms.validate efficiency_hint", function()
  local base = {
    id = "hint_room", tier = "beginner", command = "w",
    title = "Test", description = "Desc",
    before_example = "|before", after_example = "after|",
    usage_tip = "tip", start_text = "start", target_text = "target",
    base_xp = 50, optimal_keystrokes = { "w" },
  }

  it("accepts a string efficiency_hint", function()
    local r = {}; for k, v in pairs(base) do r[k] = v end
    r.efficiency_hint = "use $ to jump to line end"
    assert.is_true(rooms.validate(r))
  end)

  it("accepts a room without efficiency_hint", function()
    assert.is_true(rooms.validate(base))
  end)

  it("rejects a non-string efficiency_hint", function()
    local r = {}; for k, v in pairs(base) do r[k] = v end
    r.efficiency_hint = 42
    assert.is_false(rooms.validate(r))
  end)
end)

describe("rooms.phase_view efficiency_hint", function()
  it("surfaces efficiency_hint", function()
    local v = rooms.phase_view({ efficiency_hint = "tip text" })
    assert.equals("tip text", v.efficiency_hint)
  end)

  it("leaves efficiency_hint nil when unset", function()
    local v = rooms.phase_view({})
    assert.is_nil(v.efficiency_hint)
  end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `~/.luarocks/bin/busted tests/spec/rooms_spec.lua`
Expected: FAIL — the non-string case returns `true` (validator ignores the field), and `phase_view` returns `nil` for the "tip text" case.

- [ ] **Step 3: Write minimal implementation**

In `lua/the-vimmer/rooms.lua`, add a validator near the other optional validators (after `validate_goal`, ~line 58):

```lua
-- Validate the optional efficiency_hint field: nil or string.
local function validate_efficiency_hint(h)
  if h == nil then return true end
  return type(h) == "string"
end
```

Wire it into `validate_optional_additions`:

```lua
local function validate_optional_additions(ctx)
  if not validate_filetype(ctx.filetype) then return false end
  if not validate_cursor_start(ctx.cursor_start) then return false end
  if not validate_goal(ctx.goal) then return false end
  if not validate_efficiency_hint(ctx.efficiency_hint) then return false end
  return true
end
```

Add to `M.phase_view` (inside the returned table):

```lua
    efficiency_hint = ctx.efficiency_hint,
```

- [ ] **Step 4: Run test to verify it passes**

Run: `~/.luarocks/bin/busted tests/spec/rooms_spec.lua`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lua/the-vimmer/rooms.lua tests/spec/rooms_spec.lua
git commit -m "feat(rooms): add optional efficiency_hint field"
```

---

### Task 5: Render the comparison block on results

**Files:**
- Modify: `lua/the-vimmer/ui/results.lua` (replace the optimal block ~89-95)
- Test: none new (rendering is wired in Task 6; load-bearing logic already covered by Tasks 2-3). Manual smoke check below.

**Interfaces:**
- Consumes: `opts.run_stats` fields `keystroke_log` (raw-key array), `optimal_tokens` (token array), `optimal_count` (int), `efficiency_hint` (string|nil) — all supplied by Task 6.
- Produces: the rendered comparison block. No exported symbols.

- [ ] **Step 1: Replace the optimal block**

In `lua/the-vimmer/ui/results.lua`, replace the existing block:

```lua
  if opts.room then
    add(b.sep)
    add(b.row("  Optimal sequence:"), "VimmerTitle")
    for _, ln in ipairs(common.build_optimal_lines(opts.room, optimal_inner)) do
      add(b.row(ln), "VimmerCommand")
    end
  end
```

with:

```lua
  local diff = opts.run_stats
  local log = diff and diff.keystroke_log
  if log and #log > 0 and diff.optimal_tokens and diff.optimal_count then
    add(b.sep)
    -- "Your keys (N): ..." wrapped at optimal_inner.
    local your_parts = {}
    for _, k in ipairs(log) do your_parts[#your_parts + 1] = common.format_key(k) end
    local your_prefix = string.format("  Your keys (%d): ", #log)
    add(b.row(your_prefix), "VimmerTitle")
    for _, ln in ipairs(common.wrap_keys(your_parts, optimal_inner)) do
      add(b.row(ln), "VimmerCommand")
    end
    -- "Optimal (M): ..." token form.
    local opt_parts = {}
    for _, k in ipairs(diff.optimal_tokens) do
      opt_parts[#opt_parts + 1] = common.format_key(k)
    end
    add(b.row(string.format("  Optimal (%d):", diff.optimal_count)), "VimmerTitle")
    for _, ln in ipairs(common.wrap_keys(opt_parts, optimal_inner)) do
      add(b.row(ln), "VimmerXP")
    end
    -- Delta + hint.
    local over = #log - diff.optimal_count
    if over > 0 then
      add(b.row(string.format("  Delta: +%d keys over optimal", over)), "VimmerDamage")
      local hint = diff.efficiency_hint
        or string.format("%d keys over optimal — see sequence above", over)
      add(b.row("  Hint: " .. hint), "VimmerXP")
    else
      add(b.row("  Matched the efficient path."), "VimmerCleared")
    end
  elseif opts.room then
    -- Fallback: no key log available, show optimal only (no regression).
    add(b.sep)
    add(b.row("  Optimal sequence:"), "VimmerTitle")
    for _, ln in ipairs(common.build_optimal_lines(opts.room, optimal_inner)) do
      add(b.row(ln), "VimmerCommand")
    end
  end
```

- [ ] **Step 2: Add the `wrap_keys` helper**

The block above uses `common.wrap_keys`. Add it to `lua/the-vimmer/ui/common.lua` (after `pick_baseline`):

```lua
-- Wrap a list of already-formatted key strings into lines no wider than
-- `inner_width`, indenting continuation lines by 4 spaces. Returns a line array.
function M.wrap_keys(parts, inner_width)
  local lines = {}
  local line = "    "
  for _, tok in ipairs(parts or {}) do
    local sep = line == "    " and "" or " "
    if #line + #sep + #tok > inner_width and line ~= "    " then
      lines[#lines + 1] = line
      line = "    " .. tok
    else
      line = line .. sep .. tok
    end
  end
  if line ~= "    " then lines[#lines + 1] = line end
  return lines
end
```

- [ ] **Step 3: Write a test for `wrap_keys`**

Add to `tests/spec/ui_common_spec.lua`:

```lua
describe("ui.common.wrap_keys", function()
  it("keeps a short list on one line", function()
    local out = c.wrap_keys({ "j", "$", "r", "5" }, 40)
    assert.equals(1, #out)
    assert.equals("    j $ r 5", out[1])
  end)

  it("wraps when over width", function()
    local parts = {}
    for _ = 1, 30 do parts[#parts + 1] = "l" end
    local out = c.wrap_keys(parts, 20)
    assert.is_true(#out > 1)
    for _, ln in ipairs(out) do assert.is_true(#ln <= 20) end
  end)

  it("returns empty for empty input", function()
    assert.same({}, c.wrap_keys({}, 40))
  end)
end)
```

- [ ] **Step 4: Run the common tests**

Run: `~/.luarocks/bin/busted tests/spec/ui_common_spec.lua`
Expected: PASS (existing + new `wrap_keys` specs).

- [ ] **Step 5: Commit**

```bash
git add lua/the-vimmer/ui/results.lua lua/the-vimmer/ui/common.lua tests/spec/ui_common_spec.lua
git commit -m "feat(results): render key-sequence comparison block"
```

---

### Task 6: Plumb diff data through commands.lua

**Files:**
- Modify: `lua/the-vimmer/commands.lua` (`run_stats` table in the win flow ~117-136)
- Test: none new (manual smoke check below — the win flow needs a live Neovim session, out of headless scope).

**Interfaces:**
- Consumes: `g:keystroke_log_keys()` (Task 1), `common.pick_baseline` (Task 3), `rooms.phase_view` `efficiency_hint` (Task 4).
- Produces: `run_stats.keystroke_log`, `run_stats.optimal_tokens`, `run_stats.optimal_count`, `run_stats.efficiency_hint` — consumed by Task 5.

- [ ] **Step 1: Compute the baseline + phase view before open_results**

In `lua/the-vimmer/commands.lua`, immediately before the `d.ui.open_results(...)` call (~line 97), add:

```lua
    local common = require("the-vimmer.ui.common")
    local phase_ctx = room.is_boss and (room.phases[g.boss_phase] or room) or room
    local baseline = common.pick_baseline(phase_ctx)
    local phase_view = d.rooms.phase_view(phase_ctx)
```

(If `d.rooms` is not the alias used in this file, use the same module reference already used for `d.rooms.load_tier` at line ~103 — confirm by reading the surrounding lines.)

- [ ] **Step 2: Extend the run_stats table**

Add these fields inside the existing `run_stats = { ... }` table (after `beaten_seconds`):

```lua
          keystroke_log   = g:keystroke_log_keys(),
          optimal_tokens  = baseline and baseline.tokens or nil,
          optimal_count   = baseline and baseline.expanded_count or nil,
          efficiency_hint = phase_view.efficiency_hint,
```

- [ ] **Step 3: Run the full suite (no regressions)**

Run: `~/.luarocks/bin/busted tests/spec/`
Expected: PASS — all specs green (158 prior + new specs from Tasks 1-5).

- [ ] **Step 4: Manual smoke check in Neovim**

```bash
nvim --clean -u NORC \
  -c "set rtp+=$(pwd)" \
  -c "lua require('the-vimmer').setup({})" \
  -c "VimmerPlay beginner_hjkl"
```

Play the room inefficiently (spam `l`), clear it, and confirm the results screen shows:
- `Your keys (N): ...`
- `Optimal (4): j $ r 5`
- `Delta: +<N-4> keys over optimal`
- a `Hint:` line (fallback text, since `beginner_hjkl` has no `efficiency_hint`).

Then clear it efficiently (`j$r5`) and confirm `Matched the efficient path.` appears with no Hint line.

- [ ] **Step 5: Commit**

```bash
git add lua/the-vimmer/commands.lua
git commit -m "feat(commands): plumb keystroke diff into results run_stats"
```

---

### Task 7: Backfill one authored hint + docs

**Files:**
- Modify: `lua/rooms/beginner/hjkl.lua` (add `efficiency_hint`)
- Modify: `README.md` (room schema / "Adding rooms" section — document the optional field)
- Test: existing `rooms_spec` / reachability cover validity; no new test.

**Interfaces:**
- Consumes: `efficiency_hint` field from Task 4.
- Produces: a real authored hint proving the end-to-end path; updated docs.

- [ ] **Step 1: Add an authored hint to one room**

In `lua/rooms/beginner/hjkl.lua`, add after `usage_tip`:

```lua
  efficiency_hint = "Use $ to jump to line end instead of repeating l.",
```

- [ ] **Step 2: Document the field**

In `README.md`, in the section that lists room fields (the "Adding rooms" section added in commit 96b1af0), add a line describing `efficiency_hint`:

```markdown
- `efficiency_hint` *(optional, string)* — shown on the results screen when the
  player used more keys than the most efficient accepted path. Omit it and a
  generic fallback line is shown instead.
```

- [ ] **Step 3: Run the full suite**

Run: `~/.luarocks/bin/busted tests/spec/`
Expected: PASS — `beginner_hjkl` still loads and validates.

- [ ] **Step 4: Manual confirm the authored hint shows**

Repeat the Task 6 smoke check on `beginner_hjkl`, play inefficiently, and confirm the Hint line now reads `Use $ to jump to line end instead of repeating l.` (authored, not fallback).

- [ ] **Step 5: Commit**

```bash
git add lua/rooms/beginner/hjkl.lua README.md
git commit -m "feat(rooms): author hjkl efficiency_hint; document field"
```

---

## Self-Review

**Spec coverage:**
- Capture (spec §1) → Task 1. ✓
- `expand_keys` + `pick_baseline` (spec §2) → Tasks 2, 3. ✓
- `efficiency_hint` schema (spec §3) → Task 4. ✓
- Results display (spec §4) → Task 5 (+ `wrap_keys` helper). ✓
- commands.lua wiring (spec §5) → Task 6. ✓
- Edge cases: no log / no baseline fallback → Task 5 elseif branch; boss final-phase → Task 6 `phase_ctx`; 300 cap → Task 1; mouse/arrow passthrough → inherent in `format_key`. ✓
- Tests (spec §Testing): common_spec (Tasks 2,3,5), game_spec (Task 1), rooms_spec (Task 4). ✓
- Authored-hint backfill (spec mentions backfill over time) → Task 7 proves the path. ✓

**Placeholder scan:** No TBD/TODO; every code step shows full code; commands have expected output.

**Type consistency:** `keystroke_log` (array), `keystroke_log_keys()` accessor, `expand_keys(tokens)→array`, `pick_baseline(ctx)→{tokens,expanded_count}|nil`, `wrap_keys(parts,inner_width)→lines`, run_stats fields `keystroke_log/optimal_tokens/optimal_count/efficiency_hint` — names identical across Tasks 1-7. ✓

**Note for implementer:** Task 6 Step 1 assumes the module alias `d.rooms`/`d` matches what `commands.lua` already uses (it calls `d.rooms.load_tier`, `d.ui.open_results`, `d.progress.save`). Confirm by reading lines ~95-136 before editing.
