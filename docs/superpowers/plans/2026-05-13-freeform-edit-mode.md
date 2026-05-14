# Free-Form Edit Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace fixed-sequence keystroke matching with a keystroke-budget damage model so any valid solution clears a room while efficient play is still rewarded.

**Architecture:** `game.lua` drops sequence matching (`_acceptable_sequences`, `_seq_active`, combo). Damage is purely a function of total keystrokes vs. a per-phase budget (`ceil(#optimal_keystrokes * 1.5)`). XP gets an `efficiency_mult = clamp(optimal/used, 0.5, 3.0)`. `ui.lua` keeps the existing buffer-vs-target win check; HUD swaps combo line for budget line. `progress.lua` migrates `keys_correct`/`keys_wrong` stats to `keystrokes_used`/`keystrokes_over_budget` and updates the weakest-room metric.

**Tech Stack:** Lua 5.1+ / LuaJIT, Neovim 0.8+, busted (`~/.luarocks/bin/busted tests/spec/`).

**Spec:** `docs/superpowers/specs/2026-05-13-freeform-edit-mode-design.md`

---

## File Structure

| File | Responsibility | Action |
|------|---------------|--------|
| `lua/the-vimmer/game.lua` | Per-run state machine, damage, XP trigger | Modify — gut sequence matcher, add budget |
| `lua/the-vimmer/progress.lua` | Persistence + XP formula + ranking | Modify — rename param, migrate stats, new metric |
| `lua/the-vimmer/ui.lua` | HUD + win/death key handler | Modify — drop combo, add budget line, fix run_stats |
| `lua/the-vimmer/commands.lua` | start_flow wiring win/death payloads | Modify — rename `mistakes` → `over_budget_count`, swap run_stats fields |
| `tests/spec/game_spec.lua` | Game unit tests | Rewrite — new behavior |
| `tests/spec/progress_spec.lua` | Progress unit tests | Modify — rename param, add new tests |
| `tests/spec/rooms_spec.lua` | Room validation tests | Untouched (alternates still valid) |

No new files. Existing room data files (`lua/rooms/**/*.lua`) unchanged.

---

## Task 1: Rename `combo_mult` → `efficiency_mult` in `progress.calculate_xp`

**Files:**
- Modify: `lua/the-vimmer/progress.lua:116-125`
- Modify: `tests/spec/progress_spec.lua:27-51`

- [ ] **Step 1.1: Update existing tests to use `efficiency_mult` arg name**

The function takes 4th positional arg today. Behavior is identical (final multiplier). Rename in tests for clarity.

Replace lines 27–51 of `tests/spec/progress_spec.lua` with:

```lua
describe("progress.calculate_xp with efficiency_mult and double_xp", function()
  it("efficiency_mult=1 gives same result as base formula", function()
    assert.equals(100, progress.calculate_xp(50, 100, 0, 1, false))
  end)

  it("efficiency_mult=2 doubles the total", function()
    assert.equals(200, progress.calculate_xp(50, 100, 0, 2, false))
  end)

  it("efficiency_mult=3 triples the total", function()
    assert.equals(300, progress.calculate_xp(50, 100, 0, 3, false))
  end)

  it("efficiency_mult=0.5 halves the total (clamp floor)", function()
    assert.equals(50, progress.calculate_xp(50, 100, 0, 0.5, false))
  end)

  it("double_xp=true doubles after efficiency_mult", function()
    assert.equals(400, progress.calculate_xp(50, 100, 0, 2, true))
  end)

  it("nil efficiency_mult defaults to 1", function()
    assert.equals(100, progress.calculate_xp(50, 100, 0, nil, false))
  end)

  it("streak bonus still applies with efficiency_mult", function()
    assert.equals(300, progress.calculate_xp(50, 100, 3, 2, false))
  end)
end)
```

- [ ] **Step 1.2: Run tests to verify (existing 6 tests still pass + new clamp test fails)**

Run: `~/.luarocks/bin/busted tests/spec/progress_spec.lua`

Expected: All progress.calculate_xp tests pass except possibly the new `0.5` clamp test (currently passes — the formula already supports fractional multiplier — verify in the next step).

- [ ] **Step 1.3: Rename parameter in `progress.lua`**

Replace lines 116–125 of `lua/the-vimmer/progress.lua` with:

```lua
-- XP formula: base + HP bonus (up to +100%), +50% for streak >= 3,
-- × efficiency_mult, × 2 if double. efficiency_mult is computed by
-- game.lua as clamp(#optimal_keystrokes / keystrokes_used, 0.5, 3.0).
function M.calculate_xp(base_xp, remaining_hp, streak, efficiency_mult, double_xp)
  efficiency_mult = efficiency_mult or 1
  local hp_bonus = math.floor(remaining_hp / 100 * base_xp)
  local subtotal = base_xp + hp_bonus
  local streak_bonus = (streak >= 3) and math.floor(subtotal * 0.5) or 0
  local total = (subtotal + streak_bonus) * efficiency_mult
  if double_xp then total = total * 2 end
  return math.floor(total)
end
```

- [ ] **Step 1.4: Run tests to verify they pass**

Run: `~/.luarocks/bin/busted tests/spec/progress_spec.lua`

Expected: All tests pass.

- [ ] **Step 1.5: Commit**

```bash
git add lua/the-vimmer/progress.lua tests/spec/progress_spec.lua
git commit -m "refactor(progress): rename combo_mult to efficiency_mult in calculate_xp"
```

---

## Task 2: Migrate `room_stats` schema in `progress.lua`

**Files:**
- Modify: `lua/the-vimmer/progress.lua:39-69`
- Modify: `tests/spec/progress_spec.lua` (append new describe block at end)

- [ ] **Step 2.1: Write failing tests for new `room_stats` shape**

Append to `tests/spec/progress_spec.lua`:

```lua
describe("progress.ensure_room_stats new schema", function()
  it("initializes keystrokes_used and keystrokes_over_budget", function()
    local prog = {}
    local s = progress.ensure_room_stats(prog, "test_room")
    assert.equals(0, s.keystrokes_used)
    assert.equals(0, s.keystrokes_over_budget)
    assert.equals(0, s.attempts)
    assert.equals(0, s.clears)
    assert.equals(0, s.deaths)
    assert.equals(0, s.flawless_clears)
  end)
end)

describe("progress.record_clear_run new schema", function()
  it("accumulates keystrokes_used and keystrokes_over_budget", function()
    local prog = {}
    progress.record_clear_run(prog, "test_room", {
      keystrokes_used = 12,
      keystrokes_over_budget = 3,
      flawless_run = false,
    })
    local s = prog.room_stats.test_room
    assert.equals(12, s.keystrokes_used)
    assert.equals(3, s.keystrokes_over_budget)
    assert.equals(1, s.clears)
    assert.equals(0, s.flawless_clears)
  end)

  it("flawless_run still bumps flawless_clears", function()
    local prog = {}
    progress.record_clear_run(prog, "r", {
      keystrokes_used = 4, keystrokes_over_budget = 0, flawless_run = true,
    })
    assert.equals(1, prog.room_stats.r.flawless_clears)
  end)
end)

describe("progress.load migrates legacy room_stats", function()
  it("converts keys_correct + keys_wrong to keystrokes_used", function()
    local tmp = os.tmpname() .. ".json"
    local legacy = {
      total_xp = 50,
      cleared = {},
      streak = 0,
      room_stats = {
        old_room = {
          attempts = 5, clears = 2, deaths = 1, flawless_clears = 0,
          keys_correct = 40, keys_wrong = 10,
        },
      },
    }
    progress.save(legacy, tmp)
    local loaded = progress.load(tmp)
    local s = loaded.room_stats.old_room
    assert.equals(50, s.keystrokes_used)
    assert.equals(10, s.keystrokes_over_budget)
    assert.is_nil(s.keys_correct)
    assert.is_nil(s.keys_wrong)
    os.remove(tmp)
  end)
end)
```

- [ ] **Step 2.2: Run tests to confirm they fail**

Run: `~/.luarocks/bin/busted tests/spec/progress_spec.lua`

Expected: 4 failures (new fields not present; migration not run).

- [ ] **Step 2.3: Update `ensure_room_stats` and `record_clear_run` in `progress.lua`**

Replace lines 39–69 of `lua/the-vimmer/progress.lua` with:

```lua
-- Lazily initialise per-room stat counters; returns the stats sub-table.
function M.ensure_room_stats(prog, room_id)
  prog.room_stats = prog.room_stats or {}
  if not prog.room_stats[room_id] then
    prog.room_stats[room_id] = {
      attempts = 0,
      clears = 0,
      deaths = 0,
      flawless_clears = 0,
      keystrokes_used = 0,
      keystrokes_over_budget = 0,
    }
  end
  return prog.room_stats[room_id]
end

-- Increment attempt counter when the player starts playing (after the teach screen).
function M.record_attempt(prog, room_id)
  local s = M.ensure_room_stats(prog, room_id)
  s.attempts = s.attempts + 1
end

-- Record a successful clear: increments clears, accumulates keystroke totals, marks flawless runs.
function M.record_clear_run(prog, room_id, game_state)
  local s = M.ensure_room_stats(prog, room_id)
  s.clears = s.clears + 1
  s.keystrokes_used = s.keystrokes_used + (game_state.keystrokes_used or 0)
  s.keystrokes_over_budget = s.keystrokes_over_budget + (game_state.keystrokes_over_budget or 0)
  if game_state.flawless_run then
    s.flawless_clears = s.flawless_clears + 1
  end
end

-- Increment death counter (HP → 0 or timer expired).
function M.record_death(prog, room_id)
  local s = M.ensure_room_stats(prog, room_id)
  s.deaths = s.deaths + 1
end
```

- [ ] **Step 2.4: Add migration in `progress.load`**

Locate `M.load(path)` (around line 160). Replace its body with:

```lua
function M.load(path)
  path = path or M.default_path()
  local f = io.open(path, "r")
  if not f then return default_state() end
  local raw = f:read("*a"); f:close()
  local data = json_decode(raw)
  if not data then return default_state() end
  local def = default_state()
  local merged = vim.tbl_deep_extend("force", def, data)
  -- Migrate legacy keys_correct/keys_wrong -> keystrokes_used/keystrokes_over_budget.
  if type(merged.room_stats) == "table" then
    for _, st in pairs(merged.room_stats) do
      if st.keys_correct or st.keys_wrong then
        local kc = st.keys_correct or 0
        local kw = st.keys_wrong or 0
        st.keystrokes_used = (st.keystrokes_used or 0) + kc + kw
        st.keystrokes_over_budget = (st.keystrokes_over_budget or 0) + kw
        st.keys_correct = nil
        st.keys_wrong = nil
      end
      st.keystrokes_used = st.keystrokes_used or 0
      st.keystrokes_over_budget = st.keystrokes_over_budget or 0
    end
  end
  return merged
end
```

- [ ] **Step 2.5: Run tests to verify they pass**

Run: `~/.luarocks/bin/busted tests/spec/progress_spec.lua`

Expected: All tests pass.

- [ ] **Step 2.6: Commit**

```bash
git add lua/the-vimmer/progress.lua tests/spec/progress_spec.lua
git commit -m "feat(progress): migrate room_stats to keystrokes_used/over_budget"
```

---

## Task 3: Update `weakest_regular_room_id` metric

**Files:**
- Modify: `lua/the-vimmer/progress.lua:86-114`
- Modify: `tests/spec/progress_spec.lua` (append)

- [ ] **Step 3.1: Add failing test**

Append to `tests/spec/progress_spec.lua`:

```lua
describe("progress.weakest_regular_room_id with waste ratio", function()
  it("picks room with highest over-budget ratio among unlocked tiers", function()
    local rooms_by_tier = {
      beginner = {
        { id = "beginner_a", is_boss = false },
        { id = "beginner_b", is_boss = false },
      },
    }
    local prog = {
      cleared = {},
      room_stats = {
        beginner_a = {
          attempts = 3, clears = 2, deaths = 0, flawless_clears = 0,
          keystrokes_used = 50, keystrokes_over_budget = 5,
        },
        beginner_b = {
          attempts = 3, clears = 1, deaths = 1, flawless_clears = 0,
          keystrokes_used = 30, keystrokes_over_budget = 15,
        },
      },
    }
    assert.equals("beginner_b", progress.weakest_regular_room_id(prog, rooms_by_tier))
  end)

  it("skips bosses and rooms with zero attempts", function()
    local rooms_by_tier = {
      beginner = {
        { id = "beginner_a", is_boss = false },
        { id = "beginner_boss", is_boss = true },
      },
    }
    local prog = {
      cleared = {},
      room_stats = {
        beginner_a = {
          attempts = 1, clears = 1, deaths = 0, flawless_clears = 0,
          keystrokes_used = 10, keystrokes_over_budget = 0,
        },
        beginner_boss = {
          attempts = 1, clears = 0, deaths = 1, flawless_clears = 0,
          keystrokes_used = 100, keystrokes_over_budget = 50,
        },
      },
    }
    assert.equals("beginner_a", progress.weakest_regular_room_id(prog, rooms_by_tier))
  end)
end)
```

- [ ] **Step 3.2: Run tests to confirm failure**

Run: `~/.luarocks/bin/busted tests/spec/progress_spec.lua`

Expected: 2 failures (function still uses `keys_correct`/`keys_wrong`).

- [ ] **Step 3.3: Replace `weakest_regular_room_id` body**

Replace lines 86–114 of `lua/the-vimmer/progress.lua` with:

```lua
-- Find the regular room with the worst keystroke-waste ratio across all unlocked tiers.
-- "Waste" = keystrokes_over_budget / keystrokes_used. Highest waste = weakest room.
function M.weakest_regular_room_id(prog, rooms_by_tier)
  local tiers = require("the-vimmer.rooms").all_tiers()
  local worst_id, worst_waste = nil, -1
  for _, tier in ipairs(tiers) do
    local list = rooms_by_tier[tier] or {}
    local prereq_tier = ({ warrior = "beginner", ninja = "warrior" })[tier]
    local total_prereq = prereq_tier and #(rooms_by_tier[prereq_tier] or {}) or 0
    if M.is_tier_unlocked(tier, prog.cleared, total_prereq) then
      for _, r in ipairs(list) do
        if not r.is_boss then
          local st = prog.room_stats and prog.room_stats[r.id]
          if st and st.attempts > 0 and (st.keystrokes_used or 0) > 0 then
            local waste = (st.keystrokes_over_budget or 0) / st.keystrokes_used
            if waste > worst_waste then
              worst_waste = waste
              worst_id = r.id
            end
          end
        end
      end
    end
  end
  return worst_id
end
```

- [ ] **Step 3.4: Run tests to verify**

Run: `~/.luarocks/bin/busted tests/spec/progress_spec.lua`

Expected: All tests pass.

- [ ] **Step 3.5: Commit**

```bash
git add lua/the-vimmer/progress.lua tests/spec/progress_spec.lua
git commit -m "feat(progress): rank weakest room by keystroke waste ratio"
```

---

## Task 4: Replace `game.lua` — initial state shape

**Files:**
- Modify: `lua/the-vimmer/game.lua:29-66` (new state fields, drop combo/streak fields)

- [ ] **Step 4.1: Update `game.new` to introduce new fields**

Replace lines 29–62 of `lua/the-vimmer/game.lua` (the top of `M.new()` up to and including `_wrong_hp_cost`) with:

```lua
function M.new()
  local g = {
    state = "idle",        -- idle | teaching | playing | results
    current_room = nil,
    hp = 100,
    streak = 0,            -- rooms cleared in a row without dying

    keystrokes_used = 0,         -- total keys pressed this phase
    keystrokes_budget = 0,       -- ceil(#optimal_keystrokes * 1.5), or *1.0 under iron
    keystrokes_over_budget = 0,  -- count of over-budget keys this run (HP-draining)

    run_started_at = nil,
    run_seconds = nil,     -- wall-clock duration of the last run
    flawless_run = false,  -- true when cleared with keystrokes_used <= #optimal_keystrokes
    timer_death = false,

    last_xp = 0,
    last_efficiency_mult = 1,    -- recorded by complete_room for HUD/results
    timer_remaining = nil,
    power_ups = {},
    boss_phase = 1,
    boss_total_phases = 0,

    _mutators = {},        -- active run modifiers (rush, glass, iron…)
  }

  -- Replace the mutator table for a new run.
  function g:set_mutators(list)
    self._mutators = {}
    for _, name in ipairs(list or {}) do
      self._mutators[name] = true
    end
  end

  -- glass mutator doubles over-budget HP cost (8 vs 5).
  function g:_over_budget_cost()
    return self._mutators.glass and 8 or 5
  end

  -- iron mutator removes the 50% grace; budget collapses to optimal length.
  function g:_budget_for(optimal_count)
    if self._mutators.iron then return optimal_count end
    return math.ceil(optimal_count * 1.5)
  end
```

> Note: Keep `g:start_room`, `g:_phase_context`, and downstream methods as-is for now — Task 5 and beyond rewrite them. This step compiles even though `_acceptable_sequences` references below are stale; tests for HP/regen will fail until Task 5 lands.

- [ ] **Step 4.2: Run tests just to confirm the file still loads**

Run: `~/.luarocks/bin/busted tests/spec/game_spec.lua 2>&1 | head -20`

Expected: Many failures (combo/keys_correct/etc. gone), but no "module load" errors. If you see `attempt to index a nil value` at top-level, the file syntax is broken — fix before continuing.

- [ ] **Step 4.3: Commit (work-in-progress; following task fixes tests)**

```bash
git add lua/the-vimmer/game.lua
git commit -m "refactor(game): introduce keystroke budget state fields"
```

---

## Task 5: Rewrite `begin_play`, `register_key`, drop sequence helpers

**Files:**
- Modify: `lua/the-vimmer/game.lua:84-162` (`_reset_sequence_states`, `begin_play`, `_phase_optimal`, `register_key`)
- Modify: `lua/the-vimmer/game.lua:8-27` (delete `step_sequence_states`)
- Rewrite: `tests/spec/game_spec.lua` (HP/regen/combo/alternates/mutator describe blocks)

- [ ] **Step 5.1: Rewrite the relevant test blocks first (failing tests)**

Replace `tests/spec/game_spec.lua` lines **42–213** (the `game HP tracking`, `game streak`, `game.last_xp`, `game combo multiplier`, `game HP regen` blocks) with:

```lua
describe("game keystroke budget", function()
  local g

  before_each(function()
    g = game.new()
    g:start_room(make_room())  -- optimal {"w","b"}, budget = ceil(2*1.5) = 3
    g:begin_play()
  end)

  it("budget is ceil(optimal * 1.5) by default", function()
    assert.equals(3, g.keystrokes_budget)
  end)

  it("first key increments keystrokes_used, no HP drain", function()
    g:register_key("w")
    assert.equals(1, g.keystrokes_used)
    assert.equals(100, g.hp)
  end)

  it("keys up to budget do not drain HP", function()
    g:register_key("w"); g:register_key("x"); g:register_key("q")
    assert.equals(3, g.keystrokes_used)
    assert.equals(100, g.hp)
    assert.equals(0, g.keystrokes_over_budget)
  end)

  it("first over-budget key drains 5 HP", function()
    for _ = 1, 3 do g:register_key("z") end
    g:register_key("z")  -- 4th = over budget
    assert.equals(4, g.keystrokes_used)
    assert.equals(95, g.hp)
    assert.equals(1, g.keystrokes_over_budget)
  end)

  it("HP never goes below 0", function()
    for _ = 1, 50 do g:register_key("z") end
    assert.equals(0, g.hp)
  end)

  it("is_dead returns true at 0 HP", function()
    for _ = 1, 50 do g:register_key("z") end
    assert.is_true(g:is_dead())
  end)

  it("is_dead false above 0", function()
    g:register_key("w")
    assert.is_false(g:is_dead())
  end)

  it("register_key is a no-op outside playing state", function()
    g.state = "teaching"
    g:register_key("x")
    assert.equals(0, g.keystrokes_used)
    assert.equals(100, g.hp)
  end)

  it("register_key is a no-op when current_room is nil", function()
    local g2 = game.new()
    g2.state = "playing"
    g2:register_key("x")
    assert.equals(0, g2.keystrokes_used)
  end)
end)

describe("game streak", function()
  it("increments streak on dismiss_results", function()
    local g = game.new()
    g:start_room(make_room()); g:begin_play(); g:complete_room()
    g:dismiss_results()
    assert.equals(1, g.streak)
  end)

  it("resets streak on retry_room", function()
    local g = game.new()
    g.streak = 5
    g:start_room(make_room()); g:begin_play()
    g:retry_room()
    assert.equals(0, g.streak)
  end)

  it("retry_room returns to teaching state", function()
    local g = game.new()
    g:start_room(make_room()); g:begin_play()
    g:retry_room()
    assert.equals("teaching", g.state)
  end)
end)

describe("game.last_xp", function()
  it("flawless clear (keystrokes_used <= optimal) applies 15% bonus", function()
    local g = game.new()
    g:start_room(make_room())  -- optimal length 2
    g:begin_play()
    g:register_key("w"); g:register_key("b")
    g:complete_room()
    assert.is_true(g.flawless_run)
    -- base 50, hp_bonus floor(100/100*50)=50, subtotal 100, no streak,
    -- efficiency_mult = clamp(2/2, 0.5, 3) = 1, total 100, flawless x1.15 = 115
    assert.equals(115, g.last_xp)
  end)

  it("over-budget clear loses HP and is not flawless", function()
    local g = game.new()
    g:start_room(make_room())  -- budget 3
    g:begin_play()
    for _ = 1, 5 do g:register_key("z") end  -- 2 over budget = -10 HP
    g:complete_room()
    assert.equals(90, g.hp)
    assert.is_false(g.flawless_run)
  end)
end)
```

Also remove the old `acceptable parallel sequences` describe block (lines 382–396 of the original file). The alternates field still exists as data for the teach screen but no longer affects matching, so this test is no longer meaningful.

- [ ] **Step 5.2: Run tests to confirm failures**

Run: `~/.luarocks/bin/busted tests/spec/game_spec.lua`

Expected: Many failures around new behaviour. Failures are fine; we implement next.

- [ ] **Step 5.3: Delete `step_sequence_states` and rewrite `begin_play` + `register_key`**

In `lua/the-vimmer/game.lua`:

1. Delete lines 8–27 entirely (the `step_sequence_states` helper).
2. Replace the `_reset_sequence_states` method (lines 84–91 originally) with a `_reset_keystroke_budget` method.
3. Replace `begin_play` and `register_key` accordingly.

Concrete: after the `_budget_for` helper from Task 4 ends, the rest of `M.new()` through the end of `register_key` should read:

```lua
  -- Enter the teaching screen; does NOT start the countdown.
  function g:start_room(room)
    self.current_room = room
    self.state = "teaching"
  end

  -- Return the data table for the current boss phase, or the room itself for normal rooms.
  function g:_phase_context()
    if self.current_room.is_boss then
      return self.current_room.phases[self.boss_phase] or {}
    end
    return self.current_room
  end

  -- Return the optimal keystroke list for the current phase (used by teach screen + budget calc).
  function g:_phase_optimal()
    if not self.current_room then return {} end
    return self:_phase_context().optimal_keystrokes or {}
  end

  -- Reset per-phase keystroke counters and recompute the budget.
  function g:_reset_keystroke_budget()
    self.keystrokes_used = 0
    self.keystrokes_budget = self:_budget_for(#self:_phase_optimal())
  end

  -- Transition from teaching → playing; resets all per-room state.
  function g:begin_play()
    if not self.current_room then return end
    self.hp = 100
    self.keystrokes_over_budget = 0
    self.run_started_at = os.clock()
    self.timer_death = false
    if self.current_room.is_boss then
      self.boss_phase = 1
      self.boss_total_phases = #self.current_room.phases
      self.timer_remaining = self.current_room.time_limit
    else
      self.boss_phase = 1
      self.boss_total_phases = 0
      self.timer_remaining = self.current_room.time_limit or nil
    end
    self.state = "playing"
    self:_apply_auto_powerups()
    self:_reset_keystroke_budget()
  end

  -- Called for every keypress while state == "playing".
  -- Every key increments keystrokes_used; HP drains only for keys past the budget.
  function g:register_key(_key)
    if self.state ~= "playing" then return end
    if not self.current_room then return end
    self.keystrokes_used = self.keystrokes_used + 1
    if self.keystrokes_used > self.keystrokes_budget then
      self.keystrokes_over_budget = self.keystrokes_over_budget + 1
      self.hp = math.max(0, self.hp - self:_over_budget_cost())
    end
  end
```

- [ ] **Step 5.4: Run tests to verify the new keystroke-budget block passes**

Run: `~/.luarocks/bin/busted tests/spec/game_spec.lua --filter "keystroke budget"`

Expected: All keystroke-budget tests pass. Other blocks (streak, last_xp, boss, mutators) may still fail — fixed in following tasks.

- [ ] **Step 5.5: Commit**

```bash
git add lua/the-vimmer/game.lua tests/spec/game_spec.lua
git commit -m "feat(game): replace sequence matcher with keystroke-budget damage model"
```

---

## Task 6: Update mutator semantics (iron, glass)

**Files:**
- Modify: `lua/the-vimmer/game.lua` (no new code — helpers already in Task 4)
- Rewrite: `tests/spec/game_spec.lua` `game mutators` describe block

- [ ] **Step 6.1: Rewrite mutator tests**

Replace the `game mutators` block (originally lines 398–426) with:

```lua
describe("game mutators", function()
  it("glass raises over-budget HP cost to 8", function()
    local g = game.new()
    g:start_room(make_room())  -- budget 3
    g:set_mutators({ "glass" })
    g:begin_play()
    for _ = 1, 4 do g:register_key("z") end  -- 1 key over budget
    assert.equals(92, g.hp)
  end)

  it("iron removes budget grace (budget = optimal length)", function()
    local g = game.new()
    g:start_room(make_room({ optimal_keystrokes = { "w", "b" } }))
    g:set_mutators({ "iron" })
    g:begin_play()
    assert.equals(2, g.keystrokes_budget)
    g:register_key("w"); g:register_key("b"); g:register_key("x")
    -- third key is the first over budget (budget=2) → -5 HP
    assert.equals(95, g.hp)
  end)

  it("rush drains timer twice per tick", function()
    local g = game.new()
    g:start_room(make_room({ time_limit = 60 }))
    g:set_mutators({ "rush" })
    g:begin_play()
    g:tick_timer()
    assert.equals(58, g.timer_remaining)
  end)
end)
```

- [ ] **Step 6.2: Run tests to verify**

Run: `~/.luarocks/bin/busted tests/spec/game_spec.lua --filter "mutators"`

Expected: All three mutator tests pass (mechanics are already in `_budget_for` and `_over_budget_cost` from Task 4).

- [ ] **Step 6.3: Commit**

```bash
git add tests/spec/game_spec.lua
git commit -m "test(game): mutator semantics under keystroke-budget model"
```

---

## Task 7: Boss-phase reset of keystrokes

**Files:**
- Modify: `lua/the-vimmer/game.lua` `advance_boss_phase` method (originally lines 213–219)
- Rewrite: `tests/spec/game_spec.lua` `game boss phases` describe block

- [ ] **Step 7.1: Rewrite boss-phase tests**

Replace the `game boss phases` block (originally lines 338–380) with:

```lua
describe("game boss phases", function()
  local g

  before_each(function()
    g = game.new()
    g:start_room(make_boss_room())
    g:begin_play()
  end)

  it("begin_play sets boss_phase=1 and boss_total_phases=3", function()
    assert.equals(1, g.boss_phase)
    assert.equals(3, g.boss_total_phases)
  end)

  it("begin_play computes budget from phase 1 optimal length", function()
    -- phase 1 optimal = {"w"} → budget = ceil(1 * 1.5) = 2
    assert.equals(2, g.keystrokes_budget)
  end)

  it("advance_boss_phase increments boss_phase", function()
    g:advance_boss_phase()
    assert.equals(2, g.boss_phase)
  end)

  it("advance_boss_phase resets keystrokes_used and recomputes budget", function()
    g:register_key("w"); g:register_key("x"); g:register_key("z")
    assert.equals(3, g.keystrokes_used)
    g:advance_boss_phase()
    assert.equals(0, g.keystrokes_used)
    assert.equals(2, g.keystrokes_budget)
  end)

  it("advance_boss_phase does NOT reset HP, timer, or over-budget counter", function()
    g.hp = 70; g.timer_remaining = 45; g.keystrokes_over_budget = 2
    g:advance_boss_phase()
    assert.equals(70, g.hp)
    assert.equals(45, g.timer_remaining)
    assert.equals(2, g.keystrokes_over_budget)
  end)

  it("_phase_optimal returns phase 1 optimal keys", function()
    assert.same({"w"}, g:_phase_optimal())
  end)

  it("_phase_optimal returns phase 2 keys after advance", function()
    g:advance_boss_phase()
    assert.same({"w"}, g:_phase_optimal())
  end)
end)
```

- [ ] **Step 7.2: Run tests to confirm `advance_boss_phase` failures**

Run: `~/.luarocks/bin/busted tests/spec/game_spec.lua --filter "boss phases"`

Expected: failures on `resets keystrokes_used` and possibly the budget recomputation.

- [ ] **Step 7.3: Rewrite `advance_boss_phase` in `game.lua`**

Replace the original `advance_boss_phase` (lines 213–219) with:

```lua
  -- Move to the next boss phase; resets per-phase keystroke counters and recomputes budget.
  -- HP, timer, and the over-budget counter carry over.
  function g:advance_boss_phase()
    self.boss_phase = self.boss_phase + 1
    self:_reset_keystroke_budget()
  end
```

- [ ] **Step 7.4: Run tests to verify**

Run: `~/.luarocks/bin/busted tests/spec/game_spec.lua --filter "boss phases"`

Expected: All boss-phase tests pass.

- [ ] **Step 7.5: Commit**

```bash
git add lua/the-vimmer/game.lua tests/spec/game_spec.lua
git commit -m "feat(game): reset keystroke counters between boss phases"
```

---

## Task 8: `complete_room` — efficiency multiplier + redefined flawless

**Files:**
- Modify: `lua/the-vimmer/game.lua` `complete_room` (originally lines 223–247)
- Rewrite: `tests/spec/game_spec.lua` `game.complete_room with combo_mult` block

- [ ] **Step 8.1: Rewrite XP / complete_room tests**

Replace the `game.complete_room with combo_mult` block (originally lines 428–449) with:

```lua
describe("game.complete_room efficiency multiplier", function()
  it("optimal-length play sets efficiency_mult to 1.0 (and flawless)", function()
    local g = game.new()
    g:start_room(make_room({ optimal_keystrokes = { "w", "b" }, base_xp = 50 }))
    g:begin_play()
    g:register_key("w"); g:register_key("b")
    g:complete_room()
    assert.equals(1, g.last_efficiency_mult)
    assert.is_true(g.flawless_run)
    -- base 50 + hp_bonus 50 = 100; flawless x1.15 = 115
    assert.equals(115, g.last_xp)
  end)

  it("half-as-efficient play caps mult at 0.5", function()
    local g = game.new()
    g:start_room(make_room({ optimal_keystrokes = { "w" }, base_xp = 50 }))
    g:begin_play()
    -- budget = ceil(1 * 1.5) = 2
    for _ = 1, 10 do g:register_key("z") end  -- 9 over budget, hp drained to 100-9*5=55
    g:complete_room()
    assert.is_false(g.flawless_run)
    assert.equals(0.5, g.last_efficiency_mult)
  end)

  it("super-efficient play (impossible-short) caps mult at 3.0", function()
    -- Force the math by manipulating keystrokes_used directly.
    local g = game.new()
    g:start_room(make_room({ optimal_keystrokes = { "a","b","c","d","e","f" }, base_xp = 50 }))
    g:begin_play()
    g.keystrokes_used = 1
    g:complete_room()
    assert.equals(3, g.last_efficiency_mult)
  end)

  it("zero keystrokes (defensive) treats efficiency as 1.0", function()
    local g = game.new()
    g:start_room(make_room({ optimal_keystrokes = { "w" }, base_xp = 50 }))
    g:begin_play()
    g:complete_room()  -- never called register_key
    assert.equals(1, g.last_efficiency_mult)
    assert.is_true(g.flawless_run)
  end)

  it("double_xp power-up doubles XP and is consumed", function()
    local g = game.new()
    g:start_room(make_room({ optimal_keystrokes = { "w" }, base_xp = 50 }))
    g:begin_play()
    g:register_key("w")
    g.power_ups = { { type = "double_xp" } }
    g:complete_room()
    local progress = require("the-vimmer.progress")
    -- efficiency_mult = 1, double_xp doubles, flawless x1.15
    local base = progress.calculate_xp(50, 100, 0, 1, true)
    assert.equals(math.floor(base * 1.15), g.last_xp)
    assert.equals(0, #g.power_ups)
  end)
end)
```

- [ ] **Step 8.2: Run tests to confirm failure**

Run: `~/.luarocks/bin/busted tests/spec/game_spec.lua --filter "efficiency multiplier"`

Expected: failures because current `complete_room` still references `combo_mult` / `keys_wrong`.

- [ ] **Step 8.3: Rewrite `complete_room`**

Replace `complete_room` (originally lines 223–247) with:

```lua
  -- Finalise the room: compute efficiency_mult, calculate XP (with optional double_xp),
  -- record wall-clock time, and apply the flawless bonus.
  function g:complete_room()
    if not self.current_room then return end
    local progress = require("the-vimmer.progress")
    local double = false
    for i = #self.power_ups, 1, -1 do
      if self.power_ups[i].type == "double_xp" then
        double = true
        table.remove(self.power_ups, i)
        break
      end
    end

    local optimal_count = #self:_phase_optimal()
    local used = self.keystrokes_used
    local mult
    if used == 0 or optimal_count == 0 then
      mult = 1
    else
      mult = optimal_count / used
      if mult < 0.5 then mult = 0.5 end
      if mult > 3 then mult = 3 end
    end
    self.last_efficiency_mult = mult

    self.last_xp = progress.calculate_xp(
      self.current_room.base_xp,
      self.hp,
      self.streak,
      mult,
      double
    )
    self.run_seconds = self.run_started_at and math.max(0, os.clock() - self.run_started_at) or nil
    self.flawless_run = (used <= optimal_count)
    if self.flawless_run then
      self.last_xp = math.floor(self.last_xp * 1.15)
    end
    self.state = "results"
  end
```

- [ ] **Step 8.4: Run the full game spec**

Run: `~/.luarocks/bin/busted tests/spec/game_spec.lua`

Expected: All game_spec tests pass.

- [ ] **Step 8.5: Commit**

```bash
git add lua/the-vimmer/game.lua tests/spec/game_spec.lua
git commit -m "feat(game): compute efficiency multiplier in complete_room"
```

---

## Task 9: Update `commands.lua` win/death payloads and `run_stats`

**Files:**
- Modify: `lua/the-vimmer/commands.lua:90-160`

- [ ] **Step 9.1: Update the win payload + run_stats fields**

In `lua/the-vimmer/commands.lua`, change the `d.callbacks.emit("win", …)` payload (around line 90–96) and the `run_stats` table passed to `open_results` (around line 126–134). Replace those two sections:

```lua
    d.callbacks.emit("win", {
      room_id = room.id,
      xp = g.last_xp,
      streak = prog.streak,
      flawless = g.flawless_run,
      daily = flow_opts.daily == true,
    })
```

stays the same except the comment.

For `run_stats`, replace:

```lua
        run_stats = {
          keys_correct = g.keys_correct,
          keys_wrong = g.keys_wrong,
          seconds = run_s,
          flawless = g.flawless_run,
          new_personal_best = new_pb,
          prev_best_seconds = (not new_pb and prev_best) or nil,
          beaten_seconds = (new_pb and prev_best) or nil,
        },
```

with:

```lua
        run_stats = {
          keystrokes_used = g.keystrokes_used,
          keystrokes_over_budget = g.keystrokes_over_budget,
          keystrokes_budget = g.keystrokes_budget,
          efficiency_mult = g.last_efficiency_mult,
          seconds = run_s,
          flawless = g.flawless_run,
          new_personal_best = new_pb,
          prev_best_seconds = (not new_pb and prev_best) or nil,
          beaten_seconds = (new_pb and prev_best) or nil,
        },
```

- [ ] **Step 9.2: Update death payload**

Replace lines 146–158 (the death emit + ui.open_death opts) with:

```lua
    d.callbacks.emit("death", {
      room_id = room.id,
      timed_out = g.timer_death,
      over_budget_count = g.keystrokes_over_budget,
    })

    d.ui.open_death(room,
      function() M.start_flow(room, flow_opts) end,
      show_map,
      {
        timed_out = g.timer_death,
        over_budget_count = g.keystrokes_over_budget,
      }
    )
```

- [ ] **Step 9.3: Find any remaining `g.keys_correct` / `g.keys_wrong` references**

Run: `grep -n "g\.keys_correct\|g\.keys_wrong" lua/the-vimmer/commands.lua`

Expected: no output. If any lines come back, replace `g.keys_correct + g.keys_wrong` with `g.keystrokes_used` and `g.keys_wrong` with `g.keystrokes_over_budget`.

- [ ] **Step 9.4: Run all unit tests**

Run: `~/.luarocks/bin/busted tests/spec/`

Expected: All tests pass.

- [ ] **Step 9.5: Commit**

```bash
git add lua/the-vimmer/commands.lua
git commit -m "feat(commands): rename payload fields to keystrokes_*"
```

---

## Task 10: HUD — drop combo line, add budget line

**Files:**
- Modify: `lua/the-vimmer/ui.lua:863-940` (`pu_icons_map` through end of `update_hud`)

- [ ] **Step 10.1: Replace the combo + powerup section of `update_hud`**

Locate `update_hud` (starts around `ui.lua:866`). Replace the streak-and-combo and power-up portion (originally lines 897–920) with:

```lua
    lines[#lines+1] = string.format(" Streak  %d", game_state.streak)

    do
      local used = game_state.keystrokes_used or 0
      local budget = game_state.keystrokes_budget or 0
      local over = used > budget
      lines[#lines+1] = string.format(" Keys %d / %d", used, budget)
      hls[#hls+1] = { over and "VimmerDamage" or "VimmerTitle", #lines - 1, 1, -1 }
      if over then
        lines[#lines+1] = " OVER BUDGET — HP draining"
        hls[#hls+1] = { "VimmerTimerDanger", #lines - 1, 1, -1 }
      end
    end

    local pu_str = ""
    for _, pu in ipairs(game_state.power_ups) do
      pu_str = pu_str .. (pu_icons_map[pu.type] or "?")
    end
    if pu_str ~= "" then
      lines[#lines+1] = ""
      lines[#lines+1] = " " .. pu_str
    end
```

`hl.combo_group` and `MUTATOR_TEACH` are untouched; `hl.combo_group` may go unused but stays as dead code for now (cleaned in sub-project 6 polish bundle).

- [ ] **Step 10.2: Manual smoke check (no automated test for UI)**

Since `ui.lua` has no busted coverage, manually verify the file still parses by running:

```bash
cd /mnt/storage/apps/the_vimmer && nvim --headless -c "lua require('the-vimmer.ui')" -c "qa!" 2>&1
```

Expected: no Lua errors printed.

- [ ] **Step 10.3: Commit**

```bash
git add lua/the-vimmer/ui.lua
git commit -m "feat(ui): replace HUD combo line with keystroke-budget readout"
```

---

## Task 11: Key handler — remove regen/correct branching

**Files:**
- Modify: `lua/the-vimmer/ui.lua:990-1036` (the `vim.on_key` callback body)

- [ ] **Step 11.1: Replace the per-key feedback block**

Locate the `vim.on_key` callback inside `start_phase` (originally around `ui.lua:992`). Replace lines 998–1036 (from `local prev_streak` through the end of the `if is_correct and api.nvim_win_is_valid(play_win)` block) with:

```lua
      local hp_before = game_state.hp
      game_state:register_key(key)
      local lost_hp = game_state.hp < hp_before
      update_hud()

      if lost_hp then
        hud_pulse_feedback(string.format(
          "-%d HP  (over budget)", hp_before - game_state.hp))
        flash(play_buf, "VimmerDamage", 80)
      end

      if game_state:is_dead() then
        vim.on_key(nil, ns)
        vim.cmd("stopinsert")
        vim.schedule(function()
          multi_flash(play_buf, {
            { "VimmerDamage", 200 }, { nil, 100 }, { "VimmerDeath", 200 }
          }, on_death)
        end)
        return
      end
```

Note: `_crit_ns` and the per-row CRIT highlight are removed (depended on `is_correct`, which no longer exists). Leave the `_crit_ns = api.nvim_create_namespace(...)` declaration in place — harmless and may be repurposed later.

- [ ] **Step 11.2: Smoke check**

```bash
cd /mnt/storage/apps/the_vimmer && nvim --headless -c "lua require('the-vimmer.ui')" -c "qa!" 2>&1
```

Expected: no errors.

- [ ] **Step 11.3: Commit**

```bash
git add lua/the-vimmer/ui.lua
git commit -m "refactor(ui): simplify key handler under keystroke-budget model"
```

---

## Task 12: Results screen — update run_stats display

**Files:**
- Modify: `lua/the-vimmer/ui.lua:1147-1161` (the `run_stats` rendering inside `open_results`)
- Modify: `lua/the-vimmer/ui.lua:1300-1320` (the `open_death` mistakes line)

- [ ] **Step 12.1: Replace run_stats key-discipline render**

Replace lines 1147–1161 (the `local rs = opts.run_stats` block down through the `show_keys` branch end) with:

```lua
  local rs = opts.run_stats
  if rs then
    local used = rs.keystrokes_used or 0
    local over = rs.keystrokes_over_budget or 0
    local budget = rs.keystrokes_budget or 0
    local mult = rs.efficiency_mult or 1
    local show_keys = used > 0
    local show_time = rs.seconds ~= nil and rs.seconds > 0
    if show_keys or show_time then
      add(b.sep)
      if show_keys then
        add(b.row(string.format(
          "  Keystrokes: %d used  ·  budget %d  ·  %d over",
          used, budget, over)), "VimmerTitle")
        add(b.row(string.format(
          "  Efficiency multiplier: x%.2f", mult)), "VimmerXP")
      end
      if show_time then
        local t = fmt_run_seconds(rs.seconds)
        if rs.new_personal_best then
          if rs.beaten_seconds then
            add(b.row(string.format(
              "  Personal best: %s (was %s)",
              t, fmt_run_seconds(rs.beaten_seconds))), "VimmerXP")
          else
```

> **Important:** Only replace through the line that ends with `else` — the original code continues into more `else` branches you must NOT touch. Open the file, locate the exact original block by searching for `local hits = rs.keys_correct or 0`, and replace exactly that section.

- [ ] **Step 12.2: Update death screen "Off-pattern keys" line**

Locate `open_death` (around `ui.lua:1300`). Replace lines 1308–1310:

```lua
  local mistakes = death_opts.mistakes or 0
  if mistakes > 0 then
    add(b.row(string.format("  Off-pattern keys: %d", mistakes)), "VimmerLocked")
```

with:

```lua
  local over_budget = death_opts.over_budget_count or 0
  if over_budget > 0 then
    add(b.row(string.format("  Over-budget keys: %d", over_budget)), "VimmerLocked")
```

- [ ] **Step 12.3: Smoke check**

```bash
cd /mnt/storage/apps/the_vimmer && nvim --headless -c "lua require('the-vimmer.ui')" -c "qa!" 2>&1
```

Expected: no errors.

- [ ] **Step 12.4: Commit**

```bash
git add lua/the-vimmer/ui.lua
git commit -m "feat(ui): show keystroke budget + efficiency on results & death screens"
```

---

## Task 13: Full suite + manual playtest

**Files:**
- None — verification only

- [ ] **Step 13.1: Run entire busted suite**

Run: `~/.luarocks/bin/busted tests/spec/`

Expected: all green. If anything red, fix at the source (do not skip).

- [ ] **Step 13.2: Manual playtest checklist**

Open Neovim with the plugin loaded:

```bash
nvim --cmd "set rtp+=$PWD" -c "lua require('the-vimmer').setup({})"
```

Run through each:

1. `:VimmerPlay beginner_hjkl` → teach → play. HUD shows `Keys 0 / 6`. Type `lllll` → HUD shows `Keys 5 / 6`. Buffer matches target → win screen shows efficiency x1.00 and flawless bonus.
2. Same room, but mash 20 random keys before reaching target → death screen shows "Over-budget keys: N".
3. `:VimmerPlay beginner_boss` → 3 phases. Phase transition resets budget readout to next phase's optimal.
4. `:VimmerProgress` → still renders (uses room_stats indirectly).
5. `:VimmerDaily` after enough XP to unlock `iron` → start play → HUD `Keys 0 / N` where N = optimal length (no grace).

- [ ] **Step 13.3: Commit anything outstanding**

If any tweaks were needed, commit with a descriptive message. Otherwise:

```bash
git log --oneline -15
```

to confirm the task chain landed cleanly.

---

## Self-review notes

- **Spec coverage:** All spec sections mapped to tasks. Damage model (T4, T5), XP/efficiency (T8), HP regen removed (T5, T11), mutator updates (T6), HUD changes (T10, T11), results changes (T12), room data left intact, boss reset (T7), tests (T5–T8, T13), migration (T2).
- **Placeholder scan:** No TBDs or vague directives. Every code step shows the actual code.
- **Type consistency:** New fields used identically everywhere — `keystrokes_used`, `keystrokes_budget`, `keystrokes_over_budget`, `last_efficiency_mult`. Payload field is `over_budget_count` (singular, in `death` payload + `open_death` opts).
- **Open question carried from spec:** HUD wording landed as `Keys N / M`. Animation not added (cosmetic, deferred).
