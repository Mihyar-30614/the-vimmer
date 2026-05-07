# Game Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add boss rooms, timer, combo multiplier, HP regen, power-ups, and 15 new regular rooms to the-vimmer.

**Architecture:** Boss rooms (3 phases each, timed) anchor the mechanics — timer, combo, HP regen, and power-ups all live in `game.lua` and render in `ui.lua`. Regular rooms inherit the same systems. A two-step tier unlock (80% regular rooms → boss clear → next tier) replaces the old 80% rule.

**Tech Stack:** Lua 5.1, Neovim API (`vim.api`, `vim.loop`), busted test runner.

---

## File Map

| Action | File | Purpose |
|---|---|---|
| Modify | `lua/the-vimmer/rooms.lua` | Accept boss room schema |
| Modify | `lua/the-vimmer/game.lua` | Combo, timer, HP regen, power-ups, boss phases |
| Modify | `lua/the-vimmer/progress.lua` | Combo XP mult, boss-gate unlock logic, `is_boss_unlocked` |
| Modify | `lua/the-vimmer/highlights.lua` | Timer color groups |
| Modify | `lua/the-vimmer/ui.lua` | HUD, timer loop, boss teach, phase banner, results, map |
| Modify | `lua/the-vimmer/commands.lua` | Wire power-ups + fast-clear detection |
| Modify | `tests/spec/game_spec.lua` | Tests for new mechanics |
| Modify | `tests/spec/progress_spec.lua` | Tests for new unlock logic |
| Modify | `tests/spec/rooms_spec.lua` | Tests for boss room validation |
| Create | `lua/rooms/beginner/boss.lua` | Beginner boss room (3 phases) |
| Create | `lua/rooms/warrior/boss.lua` | Warrior boss room (3 phases) |
| Create | `lua/rooms/ninja/boss.lua` | Ninja boss room (3 phases) |
| Create | `lua/rooms/beginner/hjkl2.lua` | hjkl + count prefix challenge |
| Create | `lua/rooms/beginner/word_hop.lua` | w/b/e word motion challenge |
| Create | `lua/rooms/beginner/insert2.lua` | a/A/o/O multi-line insert |
| Create | `lua/rooms/beginner/dd_yp.lua` | dd/yy/p line reorder |
| Create | `lua/rooms/beginner/counts.lua` | Numeric prefix motions |
| Create | `lua/rooms/warrior/n_repeat.lua` | search + n/N repeat |
| Create | `lua/rooms/warrior/ft_chain.lua` | f/t/;/, chain |
| Create | `lua/rooms/warrior/visual_block.lua` | Ctrl-V visual block |
| Create | `lua/rooms/warrior/ci_combo.lua` | ci" ci( ci[ combo |
| Create | `lua/rooms/warrior/change_chain.lua` | cw/C/cc chain |
| Create | `lua/rooms/ninja/global_macro.lua` | Macro + bulk apply |
| Create | `lua/rooms/ninja/registers2.lua` | Named register workflow |
| Create | `lua/rooms/ninja/surround_obj.lua` | da"/di(/ca{ text objects |
| Create | `lua/rooms/ninja/marks.lua` | ma/'a mark jumps |
| Create | `lua/rooms/ninja/substitute.lua` | :%s global substitute |

---

## Task 1: Boss Room Schema Validation

**Files:**
- Modify: `lua/the-vimmer/rooms.lua`
- Modify: `tests/spec/rooms_spec.lua`

- [ ] **Step 1: Write failing tests for boss room validation**

Append to `tests/spec/rooms_spec.lua`:

```lua
describe("rooms.validate boss rooms", function()
  local valid_boss = {
    id = "test_boss", tier = "beginner", is_boss = true,
    command = "hjkl", title = "Boss", description = "Trial",
    usage_tip = "tip", base_xp = 300, time_limit = 120,
    phases = {
      { start_text = "a", target_text = "b", optimal_keystrokes = {"x"}, tip = "p1" },
      { start_text = "c", target_text = "d", optimal_keystrokes = {"y"}, tip = "p2" },
    },
  }

  it("accepts a valid boss room", function()
    assert.is_true(rooms.validate(valid_boss))
  end)

  it("rejects boss room missing phases", function()
    local r = {}; for k, v in pairs(valid_boss) do r[k] = v end; r.phases = nil
    assert.is_false(rooms.validate(r))
  end)

  it("rejects boss room missing time_limit", function()
    local r = {}; for k, v in pairs(valid_boss) do r[k] = v end; r.time_limit = nil
    assert.is_false(rooms.validate(r))
  end)

  it("rejects boss room with phase missing target_text", function()
    local r = {}; for k, v in pairs(valid_boss) do r[k] = v end
    r.phases = { { start_text = "a", optimal_keystrokes = {"x"}, tip = "p1" } }
    assert.is_false(rooms.validate(r))
  end)
end)
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
cd /mnt/storage/apps/the_vimmer && busted tests/spec/rooms_spec.lua
```

Expected: 4 failures about boss room validation.

- [ ] **Step 3: Update `rooms.validate` to handle boss rooms**

Replace the entire `M.validate` function in `lua/the-vimmer/rooms.lua`:

```lua
local BOSS_REQUIRED = {
  "id", "tier", "command", "title", "description",
  "usage_tip", "base_xp", "phases", "time_limit",
}

function M.validate(room)
  if room.is_boss then
    for _, field in ipairs(BOSS_REQUIRED) do
      if room[field] == nil then return false end
    end
    if type(room.phases) ~= "table" or #room.phases < 1 then return false end
    for _, phase in ipairs(room.phases) do
      if not phase.start_text or not phase.target_text or not phase.optimal_keystrokes then
        return false
      end
    end
    return true
  end
  for _, field in ipairs(REQUIRED_FIELDS) do
    if room[field] == nil then return false end
  end
  return true
end
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
busted tests/spec/rooms_spec.lua
```

Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lua/the-vimmer/rooms.lua tests/spec/rooms_spec.lua
git commit -m "feat: add boss room schema validation"
```

---

## Task 2: Combo Multiplier + HP Regen in game.lua

**Files:**
- Modify: `lua/the-vimmer/game.lua`
- Modify: `tests/spec/game_spec.lua`

- [ ] **Step 1: Write failing tests**

Append to `tests/spec/game_spec.lua`:

```lua
describe("game combo multiplier", function()
  local g

  before_each(function()
    g = game.new()
    g:start_room(make_room({ optimal_keystrokes = {"w", "b"} }))
    g:begin_play()
  end)

  it("starts at combo 0, mult 1", function()
    assert.equals(0, g.combo)
    assert.equals(1, g.combo_mult)
  end)

  it("correct key increments combo", function()
    g:register_key("w")
    assert.equals(1, g.combo)
  end)

  it("wrong key resets combo to 0", function()
    g:register_key("w"); g:register_key("w"); g:register_key("w")
    g:register_key("x")
    assert.equals(0, g.combo)
  end)

  it("combo_mult becomes 2 at combo 5", function()
    for _ = 1, 5 do g:register_key("w") end
    assert.equals(2, g.combo_mult)
  end)

  it("combo_mult becomes 3 at combo 10", function()
    for _ = 1, 10 do g:register_key("w") end
    assert.equals(3, g.combo_mult)
  end)

  it("combo_mult resets to 1 after wrong key at combo 7", function()
    for _ = 1, 7 do g:register_key("w") end
    g:register_key("x")
    assert.equals(1, g.combo_mult)
  end)
end)

describe("game HP regen", function()
  local g

  before_each(function()
    g = game.new()
    g:start_room(make_room({ optimal_keystrokes = {"w"} }))
    g:begin_play()
    g.hp = 88
  end)

  it("3 consecutive correct keys give +2 HP", function()
    g:register_key("w"); g:register_key("w"); g:register_key("w")
    assert.equals(90, g.hp)
  end)

  it("regen does not exceed 100", function()
    g.hp = 99
    g:register_key("w"); g:register_key("w"); g:register_key("w")
    assert.equals(100, g.hp)
  end)

  it("wrong key resets correct_streak, no regen", function()
    g:register_key("w"); g:register_key("w"); g:register_key("x")
    g:register_key("w"); g:register_key("w")
    assert.equals(88 - 5, g.hp)  -- only one wrong key's damage
  end)
end)
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
busted tests/spec/game_spec.lua
```

Expected: failures on combo and HP regen tests.

- [ ] **Step 3: Add combo + correct_streak fields to game state**

In `lua/the-vimmer/game.lua`, replace the `local g = { ... }` block inside `M.new()`:

```lua
  local g = {
    state = "idle",
    current_room = nil,
    hp = 100,
    streak = 0,
    last_xp = 0,
    combo = 0,
    combo_mult = 1,
    correct_streak = 0,
    timer_remaining = nil,
    power_ups = {},
    boss_phase = 1,
    boss_total_phases = 0,
  }
```

- [ ] **Step 4: Add `_phase_optimal` helper and refactor `register_key`**

Replace the entire `g:register_key` function and add `g:_phase_optimal`:

```lua
  function g:_phase_optimal()
    if not self.current_room then return {} end
    if self.current_room.is_boss then
      local phase = self.current_room.phases[self.boss_phase]
      return phase and phase.optimal_keystrokes or {}
    end
    return self.current_room.optimal_keystrokes or {}
  end

  function g:register_key(key)
    if self.state ~= "playing" then return end
    if not self.current_room then return end
    local optimal = self:_phase_optimal()
    local is_correct = false
    for _, k in ipairs(optimal) do
      if k == key then is_correct = true; break end
    end
    if is_correct then
      self.combo = self.combo + 1
      self.correct_streak = self.correct_streak + 1
      if self.correct_streak % 3 == 0 then
        self.hp = math.min(100, self.hp + 2)
      end
    else
      self.combo = 0
      self.correct_streak = 0
      self.hp = math.max(0, self.hp - 5)
    end
    self.combo_mult = self.combo >= 10 and 3 or self.combo >= 5 and 2 or 1
  end
```

- [ ] **Step 5: Run tests to confirm they pass**

```bash
busted tests/spec/game_spec.lua
```

Expected: all pass, including pre-existing HP tests.

- [ ] **Step 6: Commit**

```bash
git add lua/the-vimmer/game.lua tests/spec/game_spec.lua
git commit -m "feat: add combo multiplier and HP regen to game state"
```

---

## Task 3: Timer in game.lua

**Files:**
- Modify: `lua/the-vimmer/game.lua`
- Modify: `tests/spec/game_spec.lua`

- [ ] **Step 1: Write failing tests**

Append to `tests/spec/game_spec.lua`:

```lua
describe("game timer", function()
  local g

  before_each(function()
    g = game.new()
    g:start_room(make_room({ time_limit = 60 }))
    g:begin_play()
  end)

  it("timer_remaining set from room time_limit on begin_play", function()
    assert.equals(60, g.timer_remaining)
  end)

  it("tick_timer decrements timer_remaining", function()
    g:tick_timer()
    assert.equals(59, g.timer_remaining)
  end)

  it("tick_timer returns false while time remains", function()
    assert.is_false(g:tick_timer())
  end)

  it("tick_timer returns true and sets hp=0 at zero", function()
    g.timer_remaining = 1
    local dead = g:tick_timer()
    assert.is_true(dead)
    assert.equals(0, g.hp)
  end)

  it("no timer when room has no time_limit", function()
    local g2 = game.new()
    g2:start_room(make_room())
    g2:begin_play()
    assert.is_nil(g2.timer_remaining)
  end)

  it("tick_timer is no-op when timer_remaining is nil", function()
    local g2 = game.new()
    g2:start_room(make_room())
    g2:begin_play()
    assert.is_false(g2:tick_timer())
  end)
end)
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
busted tests/spec/game_spec.lua
```

Expected: failures on timer tests.

- [ ] **Step 3: Update `begin_play` to set timer and add `tick_timer`**

Replace the `g:begin_play` function in `lua/the-vimmer/game.lua`:

```lua
  function g:begin_play()
    if not self.current_room then return end
    self.hp = 100
    self.combo = 0
    self.combo_mult = 1
    self.correct_streak = 0
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
  end

  function g:tick_timer()
    if self.timer_remaining == nil then return false end
    self.timer_remaining = self.timer_remaining - 1
    if self.timer_remaining <= 0 then
      self.hp = 0
      return true
    end
    return false
  end
```

- [ ] **Step 4: Run tests**

```bash
busted tests/spec/game_spec.lua
```

Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lua/the-vimmer/game.lua tests/spec/game_spec.lua
git commit -m "feat: add timer to game state"
```

---

## Task 4: Power-ups in game.lua

**Files:**
- Modify: `lua/the-vimmer/game.lua`
- Modify: `tests/spec/game_spec.lua`

- [ ] **Step 1: Write failing tests**

Append to `tests/spec/game_spec.lua`:

```lua
describe("game power-ups", function()
  local g

  before_each(function()
    g = game.new()
    g:start_room(make_room({ time_limit = 60 }))
  end)

  it("starts with empty power_ups", function()
    assert.same({}, g.power_ups)
  end)

  it("grant_powerup adds to power_ups list", function()
    g:grant_powerup("hp_restore")
    assert.equals(1, #g.power_ups)
    assert.equals("hp_restore", g.power_ups[1].type)
  end)

  it("grant_powerup respects max 2 slots", function()
    g:grant_powerup("hp_restore")
    g:grant_powerup("double_xp")
    g:grant_powerup("freeze_timer")
    assert.equals(2, #g.power_ups)
  end)

  it("begin_play auto-applies hp_restore and removes it", function()
    g:grant_powerup("hp_restore")
    g:begin_play()
    g.hp = 50  -- would be set by begin_play to 100, then +30 capped at 100
    -- Actually begin_play sets hp=100 first, then applies hp_restore:
    -- hp = min(100, 100+30) = 100. So hp_restore on full HP is wasted.
    -- Test with pre-set low HP by setting after begin_play... but begin_play resets hp.
    -- Test instead that power_up is consumed:
    assert.equals(0, #g.power_ups)
  end)

  it("hp_restore adds 30 HP capped at 100 when applied", function()
    -- Grant before begin_play; begin_play resets hp to 100, then applies +30 (capped)
    -- So best test: apply manually after reducing HP
    g:begin_play()
    g.hp = 60
    g.power_ups = { { type = "hp_restore" } }
    g:_apply_auto_powerups()
    assert.equals(90, g.hp)
    assert.equals(0, #g.power_ups)
  end)

  it("activate_freeze adds seconds to timer and removes freeze_timer", function()
    g:grant_powerup("freeze_timer")
    g:begin_play()
    local before = g.timer_remaining
    g:activate_freeze(5)
    assert.equals(before + 5, g.timer_remaining)
    assert.equals(0, #g.power_ups)
  end)

  it("activate_freeze returns false when no freeze power-up held", function()
    g:begin_play()
    assert.is_false(g:activate_freeze(5))
  end)

  it("activate_freeze is no-op when timer_remaining is nil", function()
    local g2 = game.new()
    g2:start_room(make_room())
    g2:grant_powerup("freeze_timer")
    g2:begin_play()
    assert.is_nil(g2.timer_remaining)
    g2:activate_freeze(5)
    assert.is_nil(g2.timer_remaining)
  end)
end)
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
busted tests/spec/game_spec.lua
```

- [ ] **Step 3: Add power-up methods to game.lua**

Add after `g:tick_timer` in `lua/the-vimmer/game.lua`:

```lua
  function g:_apply_auto_powerups()
    for i = #self.power_ups, 1, -1 do
      if self.power_ups[i].type == "hp_restore" then
        self.hp = math.min(100, self.hp + 30)
        table.remove(self.power_ups, i)
      end
    end
  end

  function g:grant_powerup(pu_type)
    if #self.power_ups >= 2 then return end
    self.power_ups[#self.power_ups + 1] = { type = pu_type }
  end

  function g:activate_freeze(seconds)
    for i, pu in ipairs(self.power_ups) do
      if pu.type == "freeze_timer" then
        table.remove(self.power_ups, i)
        if self.timer_remaining then
          self.timer_remaining = self.timer_remaining + (seconds or 5)
        end
        return true
      end
    end
    return false
  end
```

Also update `g:begin_play` to call `_apply_auto_powerups` at the end:

```lua
  function g:begin_play()
    if not self.current_room then return end
    self.hp = 100
    self.combo = 0
    self.combo_mult = 1
    self.correct_streak = 0
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
  end
```

- [ ] **Step 4: Run tests**

```bash
busted tests/spec/game_spec.lua
```

Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lua/the-vimmer/game.lua tests/spec/game_spec.lua
git commit -m "feat: add power-up system to game state"
```

---

## Task 5: Boss Phase Tracking in game.lua

**Files:**
- Modify: `lua/the-vimmer/game.lua`
- Modify: `tests/spec/game_spec.lua`

- [ ] **Step 1: Write failing tests**

Append to `tests/spec/game_spec.lua`:

```lua
local function make_boss_room(overrides)
  local r = {
    id = "test_boss", tier = "beginner", is_boss = true,
    command = "test", base_xp = 200, time_limit = 120,
    phases = {
      { start_text = "a", target_text = "b", optimal_keystrokes = {"w"}, tip = "p1" },
      { start_text = "c", target_text = "d", optimal_keystrokes = {"w"}, tip = "p2" },
      { start_text = "e", target_text = "f", optimal_keystrokes = {"w"}, tip = "p3" },
    },
  }
  for k, v in pairs(overrides or {}) do r[k] = v end
  return r
end

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

  it("advance_boss_phase increments boss_phase", function()
    g:advance_boss_phase()
    assert.equals(2, g.boss_phase)
  end)

  it("advance_boss_phase resets combo and correct_streak", function()
    g.combo = 8; g.combo_mult = 2; g.correct_streak = 5
    g:advance_boss_phase()
    assert.equals(0, g.combo)
    assert.equals(1, g.combo_mult)
    assert.equals(0, g.correct_streak)
  end)

  it("advance_boss_phase does NOT reset HP or timer", function()
    g.hp = 70; g.timer_remaining = 45
    g:advance_boss_phase()
    assert.equals(70, g.hp)
    assert.equals(45, g.timer_remaining)
  end)

  it("_phase_optimal returns correct phase optimal keys", function()
    assert.same({"w"}, g:_phase_optimal())
    g:advance_boss_phase()
    assert.same({"w"}, g:_phase_optimal())
  end)
end)
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
busted tests/spec/game_spec.lua
```

- [ ] **Step 3: Add `advance_boss_phase` to game.lua**

Add after `g:activate_freeze` in `lua/the-vimmer/game.lua`:

```lua
  function g:advance_boss_phase()
    self.boss_phase = self.boss_phase + 1
    self.combo = 0
    self.combo_mult = 1
    self.correct_streak = 0
  end
```

- [ ] **Step 4: Run tests**

```bash
busted tests/spec/game_spec.lua
```

Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lua/the-vimmer/game.lua tests/spec/game_spec.lua
git commit -m "feat: add boss phase tracking to game state"
```

---

## Task 6: Progress — Combo XP + Boss Unlock Logic

**Files:**
- Modify: `lua/the-vimmer/progress.lua`
- Modify: `tests/spec/progress_spec.lua`

- [ ] **Step 1: Write failing tests**

Replace the `progress.is_tier_unlocked` describe block in `tests/spec/progress_spec.lua` (the one starting at line 27) with:

```lua
describe("progress.calculate_xp with combo_mult and double_xp", function()
  it("combo_mult=1 (default) gives same result as before", function()
    assert.equals(100, progress.calculate_xp(50, 100, 0, 1, false))
  end)

  it("combo_mult=2 doubles the total", function()
    -- base+hp_bonus = 100, streak_bonus = 0, *2 = 200
    assert.equals(200, progress.calculate_xp(50, 100, 0, 2, false))
  end)

  it("combo_mult=3 triples the total", function()
    assert.equals(300, progress.calculate_xp(50, 100, 0, 3, false))
  end)

  it("double_xp=true doubles after combo_mult", function()
    -- base+hp_bonus=100, *2 combo, *2 double = 400
    assert.equals(400, progress.calculate_xp(50, 100, 0, 2, true))
  end)

  it("nil combo_mult defaults to 1", function()
    assert.equals(100, progress.calculate_xp(50, 100, 0, nil, false))
  end)

  it("streak bonus still applies with combo_mult", function()
    -- subtotal=100, streak_bonus=50 → 150, *2 = 300
    assert.equals(300, progress.calculate_xp(50, 100, 3, 2, false))
  end)
end)

describe("progress.is_tier_unlocked (boss-gate system)", function()
  it("beginner is always unlocked", function()
    assert.is_true(progress.is_tier_unlocked("beginner", {}, 10))
  end)

  it("warrior locked when beginner_boss not cleared", function()
    local cleared = {}
    for i = 1, 10 do cleared["beginner_" .. i] = true end
    assert.is_false(progress.is_tier_unlocked("warrior", cleared, 10))
  end)

  it("warrior unlocked when beginner_boss cleared", function()
    assert.is_true(progress.is_tier_unlocked("warrior", { beginner_boss = true }, 10))
  end)

  it("ninja locked when warrior_boss not cleared", function()
    assert.is_false(progress.is_tier_unlocked("ninja", { beginner_boss = true }, 6))
  end)

  it("ninja unlocked when warrior_boss cleared", function()
    local cleared = { beginner_boss = true, warrior_boss = true }
    assert.is_true(progress.is_tier_unlocked("ninja", cleared, 6))
  end)
end)

describe("progress.is_boss_unlocked", function()
  it("returns false when fewer than 80% of regular rooms cleared", function()
    local cleared = { beginner_hjkl = true, beginner_hjkl2 = true }
    assert.is_false(progress.is_boss_unlocked("beginner", cleared, 10))
  end)

  it("returns true when 80% or more regular rooms cleared", function()
    local cleared = {}
    for i = 1, 8 do cleared["beginner_room" .. i] = true end
    assert.is_true(progress.is_boss_unlocked("beginner", cleared, 10))
  end)

  it("does not count boss rooms toward the 80%", function()
    local cleared = {}
    for i = 1, 7 do cleared["beginner_room" .. i] = true end
    cleared["beginner_boss"] = true  -- boss cleared, but only 7/10 regular
    assert.is_false(progress.is_boss_unlocked("beginner", cleared, 10))
  end)
end)
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
busted tests/spec/progress_spec.lua
```

Expected: failures on the new and replaced tests.

- [ ] **Step 3: Update `calculate_xp` to accept combo_mult and double_xp**

Replace `M.calculate_xp` in `lua/the-vimmer/progress.lua`:

```lua
function M.calculate_xp(base_xp, remaining_hp, streak, combo_mult, double_xp)
  combo_mult = combo_mult or 1
  local hp_bonus = math.floor(remaining_hp / 100 * base_xp)
  local subtotal = base_xp + hp_bonus
  local streak_bonus = (streak >= 3) and math.floor(subtotal * 0.5) or 0
  local total = (subtotal + streak_bonus) * combo_mult
  if double_xp then total = total * 2 end
  return math.floor(total)
end
```

- [ ] **Step 4: Update `is_tier_unlocked` to use boss-gate logic**

Replace `M.is_tier_unlocked` in `lua/the-vimmer/progress.lua`:

```lua
function M.is_tier_unlocked(tier, cleared, total_in_tier)
  if tier == "beginner" then return true end
  local boss_id = (tier == "warrior") and "beginner_boss" or "warrior_boss"
  return cleared[boss_id] == true
end
```

- [ ] **Step 5: Add `is_boss_unlocked`**

Add after `M.is_tier_unlocked` in `lua/the-vimmer/progress.lua`:

```lua
function M.is_boss_unlocked(tier, cleared, total_regular)
  local prefix = tier .. "_"
  local count = 0
  for k, v in pairs(cleared) do
    if v and k:match("^" .. prefix) and not k:match("_boss$") then
      count = count + 1
    end
  end
  return count >= math.ceil((total_regular or 1) * 0.8)
end
```

- [ ] **Step 6: Run tests**

```bash
busted tests/spec/progress_spec.lua
```

Expected: all pass.

- [ ] **Step 7: Commit**

```bash
git add lua/the-vimmer/progress.lua tests/spec/progress_spec.lua
git commit -m "feat: add combo XP multiplier and boss-gate tier unlock"
```

---

## Task 7: Timer Highlight Groups

**Files:**
- Modify: `lua/the-vimmer/highlights.lua`

- [ ] **Step 1: Add `timer_group` function and new highlight groups**

Replace the entire `lua/the-vimmer/highlights.lua`:

```lua
local M = {}

function M.hp_group(hp)
  if hp > 60 then return "VimmerHP_high"
  elseif hp > 30 then return "VimmerHP_mid"
  else return "VimmerHP_low" end
end

function M.timer_group(remaining, total)
  if not total or total == 0 then return "VimmerTimerOk" end
  local pct = remaining / total
  if pct > 0.5 then return "VimmerTimerOk"
  elseif pct > 0.25 then return "VimmerTimerWarn"
  else return "VimmerTimerDanger" end
end

function M.setup()
  local hl = vim.api.nvim_set_hl
  hl(0, "VimmerTitle",        { bold = true, fg = "#ffffff" })
  hl(0, "VimmerTierBeginner", { bold = true, fg = "#8be9fd" })
  hl(0, "VimmerTierWarrior",  { bold = true, fg = "#ffb86c" })
  hl(0, "VimmerTierNinja",    { bold = true, fg = "#ff79c6" })
  hl(0, "VimmerCleared",      { fg = "#50fa7b" })
  hl(0, "VimmerLocked",       { fg = "#6272a4" })
  hl(0, "VimmerSelected",     { bold = true, reverse = true })
  hl(0, "VimmerXP",           { bold = true, fg = "#f1fa8c" })
  hl(0, "VimmerHP_high",      { fg = "#50fa7b" })
  hl(0, "VimmerHP_mid",       { fg = "#ffb86c" })
  hl(0, "VimmerHP_low",       { fg = "#ff5555" })
  hl(0, "VimmerWin",          { bg = "#50fa7b", fg = "#282a36" })
  hl(0, "VimmerDeath",        { bold = true, fg = "#ff5555" })
  hl(0, "VimmerCommand",      { bold = true, fg = "#f1fa8c" })
  hl(0, "VimmerExample",      { fg = "#8be9fd" })
  hl(0, "VimmerTimerOk",      { bold = true, fg = "#50fa7b" })
  hl(0, "VimmerTimerWarn",    { bold = true, fg = "#ffb86c" })
  hl(0, "VimmerTimerDanger",  { bold = true, fg = "#ff5555" })
  hl(0, "VimmerBoss",         { bold = true, fg = "#ff79c6" })
  hl(0, "VimmerPhase",        { bold = true, bg = "#44475a", fg = "#ff79c6" })
end

return M
```

- [ ] **Step 2: Run existing test suite to ensure nothing broke**

```bash
busted tests/
```

Expected: all pass (highlights.lua has no tests; we just verify nothing broke).

- [ ] **Step 3: Commit**

```bash
git add lua/the-vimmer/highlights.lua
git commit -m "feat: add timer and boss highlight groups"
```

---

## Task 8: Refactor open_play — start_phase + Timer Loop + Freeze Keybind

**Files:**
- Modify: `lua/the-vimmer/ui.lua`

This is the biggest UI change. Replace `M.open_play` and `M._close_play` entirely.

- [ ] **Step 1: Add module-level timer handle variable**

In `lua/the-vimmer/ui.lua`, find the existing module-level variables near the top (after the `local _flash_ns` line) and add:

```lua
local _timer_handle = nil
```

- [ ] **Step 2: Replace `M._close_play`**

Replace the existing `M._close_play` function:

```lua
function M._close_play()
  if _play_ns then
    vim.on_key(nil, _play_ns)
    _play_ns = nil
  end
  if _timer_handle then
    _timer_handle:stop()
    _timer_handle:close()
    _timer_handle = nil
  end
  if _play_tab and api.nvim_tabpage_is_valid(_play_tab) then
    pcall(function()
      local tab = _play_tab
      _play_tab = nil
      vim.cmd(api.nvim_tabpage_get_number(tab) .. "tabclose")
    end)
  end
end
```

- [ ] **Step 3: Replace `M.open_play` with refactored version**

Replace the entire `M.open_play` function:

```lua
function M.open_play(room, game_state, on_win, on_death)
  M._close_play()
  local hl = require("the-vimmer.highlights")
  local initial_time = room.time_limit

  local target_buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(target_buf, "bufhidden", "wipe")

  local play_buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(play_buf, "bufhidden", "wipe")

  vim.cmd("tabnew")
  _play_tab = api.nvim_get_current_tabpage()
  local top_win = api.nvim_get_current_win()
  api.nvim_win_set_buf(top_win, target_buf)

  vim.cmd("belowright split")
  local play_win = api.nvim_get_current_win()
  api.nvim_win_set_buf(play_win, play_buf)
  api.nvim_set_current_win(play_win)

  vim.wo[top_win].winbar  = "%#VimmerCleared# ── TARGET ──%*"
  vim.wo[play_win].winbar = "%#VimmerTierWarrior# ── EDIT HERE ──%*"

  local function pu_icons()
    local icons = { hp_restore = "♥", freeze_timer = "❄", double_xp = "★" }
    local s = ""
    for _, pu in ipairs(game_state.power_ups) do
      s = s .. "[" .. (icons[pu.type] or "?") .. "]"
    end
    return s ~= "" and ("  " .. s) or ""
  end

  local function update_hud()
    local hp_blocks = math.ceil(game_state.hp / 10)
    local hp_bar = string.rep("█", hp_blocks) .. string.rep("░", 10 - hp_blocks)
    local hp_grp = hl.hp_group(game_state.hp)

    local timer_str = ""
    if game_state.timer_remaining then
      local mins = math.floor(game_state.timer_remaining / 60)
      local secs = game_state.timer_remaining % 60
      local t_grp = hl.timer_group(game_state.timer_remaining, initial_time)
      timer_str = string.format("  %%#%s#⏱ %d:%02d%%*", t_grp, mins, secs)
    end

    local mult_str = game_state.combo_mult > 1
      and string.format("  x%d", game_state.combo_mult) or ""

    vim.wo[play_win].statusline = string.format(
      " %%#%s#HP [%s] %d%%*%s%s  Streak %d  |  %s%s",
      hp_grp, hp_bar, game_state.hp,
      timer_str, mult_str,
      game_state.streak, room.command,
      pu_icons()
    )
  end

  local function start_timer()
    if not game_state.timer_remaining then return end
    _timer_handle = vim.loop.new_timer()
    _timer_handle:start(1000, 1000, vim.schedule_wrap(function()
      if game_state.state ~= "playing" then
        if _timer_handle then _timer_handle:stop() end
        return
      end
      local dead = game_state:tick_timer()
      update_hud()
      if dead then
        if _timer_handle then _timer_handle:stop() end
        flash(play_buf, "VimmerDeath", on_death)
      end
    end))
  end

  local function start_phase(phase_data)
    local target_lines = vim.split(phase_data.target_text, "\n")

    api.nvim_buf_set_option(target_buf, "modifiable", true)
    api.nvim_buf_set_lines(target_buf, 0, -1, false, target_lines)
    api.nvim_buf_set_option(target_buf, "modifiable", false)

    api.nvim_buf_set_lines(play_buf, 0, -1, false, vim.split(phase_data.start_text, "\n"))

    local ns = api.nvim_create_namespace("the-vimmer-keys-" .. tostring(game_state.boss_phase))
    _play_ns = ns

    vim.on_key(function(key)
      if not api.nvim_win_is_valid(play_win) then
        vim.on_key(nil, ns); return
      end
      if api.nvim_get_current_win() ~= play_win then return end

      game_state:register_key(key)
      update_hud()

      if game_state:is_dead() then
        vim.on_key(nil, ns)
        vim.schedule(function() flash(play_buf, "VimmerDeath", on_death) end)
        return
      end

      vim.schedule(function()
        if not api.nvim_buf_is_valid(play_buf) then return end
        local current = table.concat(api.nvim_buf_get_lines(play_buf, 0, -1, false), "\n")
        local target = table.concat(target_lines, "\n")
        if vim.trim(current) == vim.trim(target) then
          vim.on_key(nil, ns)
          local is_last = not room.is_boss or game_state.boss_phase >= game_state.boss_total_phases
          if is_last then
            flash(play_buf, "VimmerWin", function() on_win() end)
          else
            flash(play_buf, "VimmerWin", function()
              game_state:advance_boss_phase()
              M._show_phase_banner(play_win, game_state.boss_phase, function()
                start_phase(room.phases[game_state.boss_phase])
              end)
            end)
          end
        end
      end)
    end, ns)

    vim.keymap.set("n", "<Tab>", function()
      if game_state:activate_freeze(5) then update_hud() end
    end, { buffer = play_buf, nowait = true, silent = true })
  end

  update_hud()
  local first_phase = room.is_boss and room.phases[1] or room
  start_phase(first_phase)
  start_timer()
end
```

- [ ] **Step 4: Add `M._show_phase_banner`**

Add this new function just before `M.open_play`:

```lua
function M._show_phase_banner(win, phase_num, callback)
  local label = string.format("  ── PHASE %d ──  ", phase_num)
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_lines(buf, 0, -1, false, { label })
  api.nvim_buf_set_option(buf, "modifiable", false)
  api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  local win_width = api.nvim_win_get_width(win)
  local col = math.max(0, math.floor((win_width - #label) / 2))
  local banner_win = api.nvim_open_win(buf, false, {
    relative = "win", win = win,
    row = 2, col = col,
    width = #label, height = 1,
    style = "minimal", border = "none",
  })
  api.nvim_buf_add_highlight(buf, 0, "VimmerPhase", 0, 0, -1)
  vim.defer_fn(function()
    if api.nvim_win_is_valid(banner_win) then
      api.nvim_win_close(banner_win, true)
    end
    callback()
  end, 800)
end
```

- [ ] **Step 5: Manual test**

Open Neovim, run `:VimmerPlay beginner_hjkl`, complete teaching screen, verify:
- HUD shows HP bar
- Wrong keys reduce HP
- Correct keys do not
- Completing buffer match triggers win flash

- [ ] **Step 6: Commit**

```bash
git add lua/the-vimmer/ui.lua
git commit -m "feat: refactor open_play with start_phase, timer loop, and freeze keybind"
```

---

## Task 9: Boss Teach Screen

**Files:**
- Modify: `lua/the-vimmer/ui.lua`

- [ ] **Step 1: Update `M.open_teach` to show all boss phases**

Replace the `M.open_teach` function in `lua/the-vimmer/ui.lua`:

```lua
function M.open_teach(room, on_begin)
  local width = 60
  local b = make_border(width)
  local lines = {}
  local hls = {}

  local function add(content, group)
    lines[#lines+1] = content
    if group then hls[#hls+1] = { group, #lines - 1, 0, -1 } end
  end

  add(b.top)
  if room.is_boss then
    add(b.row("  ⚔ BOSS: " .. room.command:gsub("\n", " ↵ ")), "VimmerBoss")
    add(b.row("  " .. room.description:gsub("\n", " ↵ ")), "VimmerTitle")
    add(b.sep)
    for i, phase in ipairs(room.phases) do
      add(b.row(string.format("  PHASE %d: %s", i, phase.tip or "")), "VimmerCommand")
      add(b.row("  BEFORE: " .. phase.start_text:gsub("\n", " ↵ ")), "VimmerLocked")
      add(b.row("  AFTER:  " .. phase.target_text:gsub("\n", " ↵ ")), "VimmerCleared")
      if i < #room.phases then add(b.row("")) end
    end
  else
    add(b.row("  COMMAND: " .. room.command:gsub("\n", " ↵ ")), "VimmerCommand")
    add(b.row("  " .. room.description:gsub("\n", " ↵ ")), "VimmerTitle")
    add(b.sep)
    add(b.row("  BEFORE:  " .. room.before_example:gsub("\n", " ↵ ")), "VimmerLocked")
    add(b.row("  AFTER:   " .. room.after_example:gsub("\n", " ↵ ")), "VimmerCleared")
    add(b.row(""))
    local tip = room.usage_tip
    while #tip > 56 do
      local cut = tip:sub(1, 56):match("^(.+) ")
      add(b.row("  " .. (cut or tip:sub(1, 56))))
      tip = tip:sub(#(cut or tip:sub(1, 56)) + 2)
    end
    if #tip > 0 then add(b.row("  " .. tip)) end
  end
  add(b.sep)
  add(b.row("  <Enter> to begin   <q> back"))
  add(b.bot)

  local buf, win = open_float(lines, width)
  apply_hl(buf, hls)

  if not room.is_boss then
    for _, li in ipairs({ 4, 5 }) do
      local row = lines[li + 1]
      if row then
        local pipe = row:find("|", 1, true)
        if pipe then
          api.nvim_buf_add_highlight(buf, 0, "VimmerExample", li, pipe - 1, pipe)
        end
      end
    end
  end

  vim.keymap.set("n", "<CR>", function()
    api.nvim_win_close(win, true)
    on_begin()
  end, { buffer = buf, nowait = true, silent = true })

  vim.keymap.set("n", "q", function()
    api.nvim_win_close(win, true)
  end, { buffer = buf, nowait = true, silent = true })
end
```

- [ ] **Step 2: Manual test**

Open Neovim. Once `beginner_boss.lua` exists (Task 15), test with `:VimmerPlay beginner_boss` to verify the 3-phase teach screen renders. For now, verify existing rooms still show correctly with `:VimmerPlay beginner_hjkl`.

- [ ] **Step 3: Commit**

```bash
git add lua/the-vimmer/ui.lua
git commit -m "feat: boss teach screen shows all phases"
```

---

## Task 10: Results Screen — Boss Victory + Power-up Choice

**Files:**
- Modify: `lua/the-vimmer/ui.lua`

- [ ] **Step 1: Replace `M.open_results` with extended version**

Replace the entire `M.open_results` function:

```lua
function M.open_results(xp_earned, hp_remaining, streak, unlocked_tier, on_continue, opts)
  opts = opts or {}
  local is_boss = opts.is_boss
  local fast_clear = opts.fast_clear
  local on_powerup = opts.on_powerup

  local width = 60
  local b = make_border(width)
  local all_lines = {}
  local hls = {}

  local function add(content, group)
    all_lines[#all_lines+1] = content
    if group then hls[#hls+1] = { group, #all_lines - 1, 0, -1 } end
  end

  add(b.top)
  if is_boss then
    add(b.row("  ⚔ BOSS CLEARED!"), "VimmerBoss")
  else
    add(b.row("  ROOM CLEARED!"), "VimmerWin")
  end
  add(b.sep)
  add(b.row(string.format("  XP Earned:     +%d", xp_earned)), "VimmerXP")
  add(b.row(string.format("  HP Remaining:  %d / 100", hp_remaining)), "VimmerTitle")
  add(b.row(string.format("  Streak:        %d", streak)), "VimmerTierWarrior")

  if unlocked_tier then
    local tier_name = unlocked_tier:lower()
    local tier_grp = ({ warrior = "VimmerTierWarrior", ninja = "VimmerTierNinja" })[tier_name]
      or "VimmerTierBeginner"
    add(b.sep)
    add(b.row("  NEW TIER UNLOCKED:"), "VimmerTitle")
    add(b.row("  " .. unlocked_tier), tier_grp)
  end

  local powerup_section_start = nil
  if fast_clear and on_powerup then
    add(b.sep)
    add(b.row("  ⚡ FAST CLEAR! Choose a power-up:"), "VimmerXP")
    powerup_section_start = #all_lines + 1
    add(b.row("    ♥  +30 HP next room"))
    add(b.row("    ❄  Freeze timer 5s"))
    add(b.row("    ★  Double XP next room"))
  end

  add(b.sep)
  local footer_line = #all_lines + 1
  if fast_clear and on_powerup then
    add(b.row("  j/k choose   <Enter> pick"))
  else
    add(b.row("  <Enter> next room   <q> map"))
  end
  add(b.bot)

  local empty = {}
  for _ = 1, #all_lines do empty[#empty+1] = "" end
  local buf, win = open_float(empty, width)

  local revealed = 0
  local function reveal_next()
    if not api.nvim_buf_is_valid(buf) then return end
    revealed = revealed + 1
    api.nvim_buf_set_option(buf, "modifiable", true)
    api.nvim_buf_set_lines(buf, revealed - 1, revealed, false, { all_lines[revealed] })
    api.nvim_buf_set_option(buf, "modifiable", false)
    for _, h in ipairs(hls) do
      if h[2] == revealed - 1 then
        api.nvim_buf_add_highlight(buf, 0, h[1], h[2], h[3], h[4])
      end
    end
    if revealed < #all_lines then
      vim.defer_fn(reveal_next, 80)
    else
      -- all lines revealed — wire keybindings
      if fast_clear and on_powerup and powerup_section_start then
        local pu_types = { "hp_restore", "freeze_timer", "double_xp" }
        local sel_ns = api.nvim_create_namespace("the-vimmer-pu-sel")
        local cur = 1
        local function update_pu_sel()
          api.nvim_buf_clear_namespace(buf, sel_ns, 0, -1)
          local line = powerup_section_start + cur - 2
          api.nvim_buf_add_highlight(buf, sel_ns, "VimmerSelected", line, 0, -1)
        end
        update_pu_sel()
        vim.keymap.set("n", "j", function()
          cur = math.min(cur + 1, 3); update_pu_sel()
        end, { buffer = buf, nowait = true, silent = true })
        vim.keymap.set("n", "k", function()
          cur = math.max(cur - 1, 1); update_pu_sel()
        end, { buffer = buf, nowait = true, silent = true })
        vim.keymap.set("n", "<CR>", function()
          on_powerup(pu_types[cur])
          -- re-render footer as normal continue
          api.nvim_buf_set_option(buf, "modifiable", true)
          api.nvim_buf_set_lines(buf, footer_line - 1, footer_line, false,
            { b.row("  <Enter> next room   <q> map") })
          api.nvim_buf_set_option(buf, "modifiable", false)
          api.nvim_buf_clear_namespace(buf, sel_ns, 0, -1)
          vim.keymap.del("n", "j", { buffer = buf })
          vim.keymap.del("n", "k", { buffer = buf })
          vim.keymap.set("n", "<CR>", function()
            api.nvim_win_close(win, true); on_continue(false)
          end, { buffer = buf, nowait = true, silent = true })
          vim.keymap.set("n", "q", function()
            api.nvim_win_close(win, true); on_continue(true)
          end, { buffer = buf, nowait = true, silent = true })
        end, { buffer = buf, nowait = true, silent = true })
      else
        vim.keymap.set("n", "<CR>", function()
          api.nvim_win_close(win, true); on_continue(false)
        end, { buffer = buf, nowait = true, silent = true })
        vim.keymap.set("n", "q", function()
          api.nvim_win_close(win, true); on_continue(true)
        end, { buffer = buf, nowait = true, silent = true })
      end
    end
  end

  vim.defer_fn(reveal_next, 80)
end
```

- [ ] **Step 2: Manual test**

Test in Neovim: `:VimmerPlay beginner_hjkl`, complete the room, verify results screen still animates and <Enter>/<q> work. (Power-up path tested in Task 14 after wiring commands.lua.)

- [ ] **Step 3: Commit**

```bash
git add lua/the-vimmer/ui.lua
git commit -m "feat: results screen supports boss victory and power-up choice"
```

---

## Task 11: Map — Boss Room Rendering

**Files:**
- Modify: `lua/the-vimmer/ui.lua`

- [ ] **Step 1: Replace the tier-rendering loop inside `M.open_map`**

The current loop (lines 99–122) renders tiers. Replace it so boss rooms render separately at the bottom of each tier. Replace the entire `for ti, tier in ipairs(tiers)` block:

```lua
  for ti, tier in ipairs(tiers) do
    local all_tier_rooms = rooms_by_tier[tier] or {}
    local tier_rooms = {}
    local boss_room = nil
    for _, room in ipairs(all_tier_rooms) do
      if room.is_boss then boss_room = room
      else tier_rooms[#tier_rooms+1] = room end
    end

    local prereq_tier = ({ warrior = "beginner", ninja = "warrior" })[tier]
    local total_prereq = prereq_tier and #(rooms_by_tier[prereq_tier] or {}) or 0
    local unlocked = progress.is_tier_unlocked(tier, progress_data.cleared, total_prereq)

    if not unlocked then
      add(b.row(string.format("  [%s]  locked — %s",
        tier_labels[tier], tier_prereq[tier] or "")), "VimmerLocked")
    else
      add(b.row(string.format("  [%s]", tier_labels[tier])), tier_colors[tier])
      for _, room in ipairs(tier_rooms) do
        local cleared = progress_data.cleared[room.id]
        local icon = cleared and "✓" or "►"
        local label = string.format("   %s  %s", icon, room.title:sub(1, 46))
        if cleared then
          add(b.row(label), "VimmerCleared")
        else
          add(b.row(label))
          selectable[#selectable+1] = { line = #lines, room = room }
        end
      end
      -- boss room at bottom of tier
      if boss_room then
        local boss_cleared = progress_data.cleared[boss_room.id]
        local boss_unlocked = progress.is_boss_unlocked(tier, progress_data.cleared, #tier_rooms)
        if boss_cleared then
          add(b.row("   ✓ ⚔  " .. boss_room.title:sub(1, 42)), "VimmerCleared")
        elseif boss_unlocked then
          add(b.row("   ► ⚔  " .. boss_room.title:sub(1, 42)), "VimmerBoss")
          selectable[#selectable+1] = { line = #lines, room = boss_room }
        else
          add(b.row("     ⚔  " .. boss_room.title:sub(1, 42) .. "  [80% first]"), "VimmerLocked")
        end
      end
    end
    if ti < #tiers then add(b.row("")) end
  end
```

- [ ] **Step 2: Manual test**

Once boss room files exist (Task 15), run `:VimmerPlay` to open the map and verify boss rooms appear at the bottom of each tier. Before clearing 80%, they should show as locked. After clearing 80% (you can manually edit the save file or clear rooms in game), verify boss becomes selectable.

- [ ] **Step 3: Commit**

```bash
git add lua/the-vimmer/ui.lua
git commit -m "feat: map renders boss rooms at tier bottom with lock/unlock state"
```

---

## Task 12: Wire Power-ups + Fast Clear in commands.lua

**Files:**
- Modify: `lua/the-vimmer/commands.lua`

- [ ] **Step 1: Update `complete_room` call and results call in `on_win`**

Replace the `on_win` function inside `start_flow` in `lua/the-vimmer/commands.lua`:

```lua
  local function on_win()
    d.ui._close_play()
    g:complete_room()

    prog.cleared[room.id] = true
    prog.total_xp = (prog.total_xp or 0) + g.last_xp
    g:dismiss_results()
    prog.streak = g.streak
    local unlocked_msg = check_newly_unlocked(d, prog, rooms_by_tier)
    d.progress.save(prog)

    local fast_clear = room.time_limit ~= nil
      and g.timer_remaining ~= nil
      and g.timer_remaining > room.time_limit * 0.5

    d.ui.open_results(g.last_xp, g.hp, g.streak, unlocked_msg,
      function(go_map)
        if go_map then
          show_map()
          return
        end
        local tier_rooms = d.rooms.load_tier(room.tier)
        local next_room = nil
        for i, r in ipairs(tier_rooms) do
          if r.id == room.id and tier_rooms[i + 1] then
            next_room = tier_rooms[i + 1]
            break
          end
        end
        if next_room then
          start_flow(next_room)
        else
          show_map()
        end
      end,
      {
        is_boss = room.is_boss,
        fast_clear = fast_clear,
        on_powerup = function(pu_type) g:grant_powerup(pu_type) end,
      })
  end
```

- [ ] **Step 2: Update `complete_room` to pass combo_mult to XP calculation**

`g:complete_room()` in game.lua calls `progress.calculate_xp` internally. We already updated `calculate_xp` to accept `combo_mult`. Update `g:complete_room` in `lua/the-vimmer/game.lua`:

```lua
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
    self.last_xp = progress.calculate_xp(
      self.current_room.base_xp,
      self.hp,
      self.streak,
      self.combo_mult,
      double
    )
    self.state = "results"
  end
```

- [ ] **Step 3: Add test for complete_room with combo_mult**

Append to `tests/spec/game_spec.lua`:

```lua
describe("game.complete_room with combo_mult", function()
  it("applies combo_mult to XP", function()
    local g = game.new()
    g:start_room(make_room({ base_xp = 50 })); g:begin_play()
    g.combo_mult = 2
    g:complete_room()
    local progress = require("the-vimmer.progress")
    -- calculate_xp(50, 100, 0, 2, false) = (50+50)*2 = 200
    assert.equals(200, g.last_xp)
  end)

  it("double_xp power-up doubles XP and is consumed", function()
    local g = game.new()
    g:start_room(make_room({ base_xp = 50 })); g:begin_play()
    g.power_ups = { { type = "double_xp" } }
    g:complete_room()
    -- calculate_xp(50, 100, 0, 1, true) = 100*2 = 200
    assert.equals(200, g.last_xp)
    assert.equals(0, #g.power_ups)
  end)
end)
```

- [ ] **Step 4: Run tests**

```bash
busted tests/spec/game_spec.lua
```

Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lua/the-vimmer/commands.lua lua/the-vimmer/game.lua tests/spec/game_spec.lua
git commit -m "feat: wire power-ups and fast-clear detection into game flow"
```

---

## Task 13: Run Full Test Suite

- [ ] **Step 1: Run all tests**

```bash
cd /mnt/storage/apps/the_vimmer && busted tests/
```

Expected: all pass. If any fail, fix before proceeding.

- [ ] **Step 2: Commit any fixes**

```bash
git add -p
git commit -m "fix: resolve any remaining test failures before adding room content"
```

---

## Task 14: Boss Room Files

**Files:**
- Create: `lua/rooms/beginner/boss.lua`
- Create: `lua/rooms/warrior/boss.lua`
- Create: `lua/rooms/ninja/boss.lua`

- [ ] **Step 1: Create `lua/rooms/beginner/boss.lua`**

```lua
return {
  id = "beginner_boss",
  tier = "beginner",
  is_boss = true,
  command = "hjkl + insert + delete",
  title = "BOSS: The Gauntlet",
  description = "Three-phase trial. All beginner skills tested.",
  usage_tip = "Use everything you have learned: navigate, insert, delete.",
  base_xp = 300,
  time_limit = 120,
  phases = {
    {
      tip = "Phase 1: Navigate to each X and delete it",
      start_text = "keep\nX\nkeep\nX\nkeep\nX\nkeep",
      target_text = "keep\n\nkeep\n\nkeep\n\nkeep",
      optimal_keystrokes = { "j", "d", "d", "k" },
    },
    {
      tip = "Phase 2: Append ! to every line",
      start_text = "alpha\nbeta\ngamma\ndelta",
      target_text = "alpha!\nbeta!\ngamma!\ndelta!",
      optimal_keystrokes = { "A", "!", "\27", "j" },
    },
    {
      tip = "Phase 3: Reorder the lines to match the target",
      start_text = "third\nfirst\nsecond",
      target_text = "first\nsecond\nthird",
      optimal_keystrokes = { "d", "d", "p", "j", "k", "G", "p" },
    },
  },
}
```

- [ ] **Step 2: Create `lua/rooms/warrior/boss.lua`**

```lua
return {
  id = "warrior_boss",
  tier = "warrior",
  is_boss = true,
  command = "f/t + visual + macros",
  title = "BOSS: The Siege",
  description = "Three-phase trial. Search, visual block, and macros.",
  usage_tip = "Chain f-motion, visual block, then record and replay a macro.",
  base_xp = 450,
  time_limit = 150,
  phases = {
    {
      tip = "Phase 1: Use f-motion to reach each colon and delete it",
      start_text = "key1: val1\nkey2: val2\nkey3: val3",
      target_text = "key1 val1\nkey2 val2\nkey3 val3",
      optimal_keystrokes = { "f", ":", "x", "j", ";", "x", "j", ";", "x" },
    },
    {
      tip = "Phase 2: Visual block — add '# ' prefix to all 5 lines",
      start_text = "line one\nline two\nline three\nline four\nline five",
      target_text = "# line one\n# line two\n# line three\n# line four\n# line five",
      optimal_keystrokes = { "\22", "4", "j", "I", "#", " ", "\27" },
    },
    {
      tip = "Phase 3: Record macro qa, apply to remaining lines with 3@a",
      start_text = "foo\nfoo\nfoo\nfoo",
      target_text = "bar\nbar\nbar\nbar",
      optimal_keystrokes = { "q", "a", "c", "i", "w", "b", "a", "r", "\27", "j", "q", "3", "@", "a" },
    },
  },
}
```

- [ ] **Step 3: Create `lua/rooms/ninja/boss.lua`**

```lua
return {
  id = "ninja_boss",
  tier = "ninja",
  is_boss = true,
  command = "registers + text-objects + macros",
  title = "BOSS: The Void",
  description = "Three-phase trial. Registers, text objects, macro composition.",
  usage_tip = "Yank into named registers, delete with text objects, record complex macros.",
  base_xp = 600,
  time_limit = 180,
  phases = {
    {
      tip = "Phase 1: Use register 'a' to yank then paste in reverse",
      start_text = "alpha\nbeta\n[here]",
      target_text = "alpha\nbeta\nalpha",
      optimal_keystrokes = { '"', "a", "y", "y", "2", "j", "d", "d", '"', "a", "p" },
    },
    {
      tip = "Phase 2: Use text objects to strip quotes from each value",
      start_text = 'x = "foo"\ny = "bar"\nz = "baz"',
      target_text = "x = foo\ny = bar\nz = baz",
      optimal_keystrokes = { "d", "i", '"', "j", ".", "j", "." },
    },
    {
      tip = "Phase 3: Macro + text object to bulk-change var to const",
      start_text = "var a = 1\nvar b = 2\nvar c = 3\nvar d = 4",
      target_text = "const a = 1\nconst b = 2\nconst c = 3\nconst d = 4",
      optimal_keystrokes = { "q", "a", "c", "i", "w", "c", "o", "n", "s", "t", "\27", "j", "q", "3", "@", "a" },
    },
  },
}
```

- [ ] **Step 4: Verify rooms load**

```bash
busted tests/spec/rooms_spec.lua
```

Expected: all pass. The `load_tier` tests will now pick up boss rooms.

- [ ] **Step 5: Commit**

```bash
git add lua/rooms/beginner/boss.lua lua/rooms/warrior/boss.lua lua/rooms/ninja/boss.lua
git commit -m "feat: add boss rooms for all three tiers"
```

---

## Task 15: New Beginner Rooms

**Files:**
- Create: `lua/rooms/beginner/hjkl2.lua`
- Create: `lua/rooms/beginner/word_hop.lua`
- Create: `lua/rooms/beginner/insert2.lua`
- Create: `lua/rooms/beginner/dd_yp.lua`
- Create: `lua/rooms/beginner/counts.lua`

- [ ] **Step 1: Create `lua/rooms/beginner/hjkl2.lua`**

```lua
return {
  id = "beginner_hjkl2",
  tier = "beginner",
  command = "Nj / Nk / Nl / Nh",
  title = "Count Motions",
  description = "Prefix hjkl with a number to move multiple steps at once",
  before_example = "|first\nsecond\nthird",
  after_example = "first\nsecond\n|third",
  usage_tip = "3j moves 3 lines down. 5l moves 5 chars right. No arrow keys.",
  start_text = "first\nsecond\nthird\nfourth\nFIFTH",
  target_text = "first\nsecond\nthird\nfourth\nfifth",
  base_xp = 40,
  time_limit = 30,
  optimal_keystrokes = { "4", "j", "~", "~", "~", "~", "~" },
}
```

- [ ] **Step 2: Create `lua/rooms/beginner/word_hop.lua`**

```lua
return {
  id = "beginner_word_hop",
  tier = "beginner",
  command = "w / b / e",
  title = "Word Motions: w, b, e",
  description = "w = next word, b = back word, e = end of word",
  before_example = "|one two three",
  after_example = "one |two three",
  usage_tip = "w hops forward one word. 2w hops two words. b reverses.",
  start_text = "the quick brown fox jumps",
  target_text = "the quick green fox jumps",
  base_xp = 40,
  time_limit = 35,
  optimal_keystrokes = { "2", "w", "c", "w", "g", "r", "e", "e", "n", "\27" },
}
```

- [ ] **Step 3: Create `lua/rooms/beginner/insert2.lua`**

```lua
return {
  id = "beginner_insert2",
  tier = "beginner",
  command = "a / A / o / O",
  title = "Insert Variants",
  description = "A = append at end of line. o = open line below. O = open line above.",
  before_example = "hello|",
  after_example = "hello!",
  usage_tip = "A puts you at end of line in insert mode. o opens a new line below.",
  start_text = "alpha\nbeta\ngamma",
  target_text = "alpha!\nbeta!\ngamma!",
  base_xp = 50,
  time_limit = 40,
  optimal_keystrokes = { "A", "!", "\27", "j", "A", "!", "\27", "j", "A", "!", "\27" },
}
```

- [ ] **Step 4: Create `lua/rooms/beginner/dd_yp.lua`**

```lua
return {
  id = "beginner_dd_yp",
  tier = "beginner",
  command = "dd / yy / p",
  title = "Cut, Copy, Paste Lines",
  description = "dd cuts a line, yy copies it, p pastes below cursor",
  before_example = "b\n|a",
  after_example = "|a\nb",
  usage_tip = "dd on a line deletes it into the register. p pastes it after cursor line.",
  start_text = "banana\napple\ncherry",
  target_text = "apple\nbanana\ncherry",
  base_xp = 45,
  time_limit = 30,
  optimal_keystrokes = { "d", "d", "p" },
}
```

- [ ] **Step 5: Create `lua/rooms/beginner/counts.lua`**

```lua
return {
  id = "beginner_counts",
  tier = "beginner",
  command = "N<motion> / Ndd",
  title = "Numeric Prefixes",
  description = "Any motion or operator can be prefixed with a count: 3w, 2dd, 5x",
  before_example = "|aaa bbb ccc ddd eee",
  after_example = "|aaa bbb ccc",
  usage_tip = "4w jumps 4 words. 2dd deletes 2 lines. Counts multiply the action.",
  start_text = "aaa bbb ccc ddd eee\nextra line",
  target_text = "aaa bbb ccc\nextra line",
  base_xp = 45,
  time_limit = 25,
  optimal_keystrokes = { "3", "w", "d", "$" },
}
```

- [ ] **Step 6: Run test suite**

```bash
busted tests/
```

Expected: all pass.

- [ ] **Step 7: Commit**

```bash
git add lua/rooms/beginner/hjkl2.lua lua/rooms/beginner/word_hop.lua \
  lua/rooms/beginner/insert2.lua lua/rooms/beginner/dd_yp.lua \
  lua/rooms/beginner/counts.lua
git commit -m "feat: add 5 new beginner rooms"
```

---

## Task 16: New Warrior Rooms

**Files:**
- Create: `lua/rooms/warrior/n_repeat.lua`
- Create: `lua/rooms/warrior/ft_chain.lua`
- Create: `lua/rooms/warrior/visual_block.lua`
- Create: `lua/rooms/warrior/ci_combo.lua`
- Create: `lua/rooms/warrior/change_chain.lua`

- [ ] **Step 1: Create `lua/rooms/warrior/n_repeat.lua`**

```lua
return {
  id = "warrior_n_repeat",
  tier = "warrior",
  command = "/pattern + n + ciw",
  title = "Search and Replace (manual)",
  description = "Search for a pattern, jump to each match with n, change with ciw",
  before_example = "|foo …  foo",
  after_example = "|bar …  bar",
  usage_tip = "/foo<CR> finds first match. n jumps to next. ciw changes the word. . repeats.",
  start_text = "foo is good and foo does great foo things with foo",
  target_text = "bar is good and bar does great bar things with bar",
  base_xp = 80,
  time_limit = 60,
  optimal_keystrokes = { "/", "f", "o", "o", "\r", "c", "i", "w", "b", "a", "r", "\27", "n", ".", "n", ".", "n", "." },
}
```

- [ ] **Step 2: Create `lua/rooms/warrior/ft_chain.lua`**

```lua
return {
  id = "warrior_ft_chain",
  tier = "warrior",
  command = "f / t / ; / ,",
  title = "f/t Motion Chain",
  description = "f finds a char on the line. ; repeats forward. , reverses.",
  before_example = "one, two, |three",
  after_example = "one, two, |FOUR",
  usage_tip = "ff finds next 'f'. ; jumps to the one after. , goes back. t stops before the char.",
  start_text = "print(hello, world, foo)",
  target_text = "print(hello, world, bar)",
  base_xp = 70,
  time_limit = 30,
  optimal_keystrokes = { "f", "f", "c", "w", "b", "a", "r", "\27" },
}
```

- [ ] **Step 3: Create `lua/rooms/warrior/visual_block.lua`**

```lua
return {
  id = "warrior_visual_block",
  tier = "warrior",
  command = "<C-v> + I",
  title = "Visual Block Insert",
  description = "Ctrl-v selects a vertical block. I inserts at every selected line simultaneously.",
  before_example = "|item one\nitem two",
  after_example = "|- item one\n- item two",
  usage_tip = "<C-v> enters visual block. Select lines with j. I to insert. <Esc> applies to all.",
  start_text = "item one\nitem two\nitem three\nitem four\nitem five",
  target_text = "- item one\n- item two\n- item three\n- item four\n- item five",
  base_xp = 85,
  time_limit = 30,
  optimal_keystrokes = { "\22", "4", "j", "I", "-", " ", "\27" },
}
```

- [ ] **Step 4: Create `lua/rooms/warrior/ci_combo.lua`**

```lua
return {
  id = "warrior_ci_combo",
  tier = "warrior",
  command = "ci\" / ci( / ci[",
  title = "Change Inside Combo",
  description = "ci<delim> changes everything inside the given delimiter pair",
  before_example = 'greet("|World")',
  after_example = 'greet("|Vim")',
  usage_tip = 'ci" changes inside double quotes. ci( changes inside parens. Works on any delimiter.',
  start_text = 'greet("World")\nmath.abs(-42)\ndata["key"]',
  target_text = 'greet("Vim")\nmath.abs(-1)\ndata["val"]',
  base_xp = 90,
  time_limit = 50,
  optimal_keystrokes = { "c", "i", '"', "V", "i", "m", "\27", "j", "c", "i", "(", "-", "1", "\27", "j", "c", "i", "[", "v", "a", "l", "\27" },
}
```

- [ ] **Step 5: Create `lua/rooms/warrior/change_chain.lua`**

```lua
return {
  id = "warrior_change_chain",
  tier = "warrior",
  command = "cw / C / cc",
  title = "Change Commands",
  description = "cw changes a word. C changes to end of line. cc changes the whole line.",
  before_example = "|old_func(old_arg)",
  after_example = "|new_func(new_arg)",
  usage_tip = "cw replaces from cursor to end of word. C replaces from cursor to end of line.",
  start_text = "old_func(old_arg)\nold_func(old_arg)",
  target_text = "new_func(new_arg)\nnew_func(new_arg)",
  base_xp = 75,
  time_limit = 45,
  optimal_keystrokes = { "c", "w", "n", "e", "w", "_", "f", "u", "n", "c", "\27", "f", "(", "c", "w", "n", "e", "w", "_", "a", "r", "g", "\27", "j", "." },
}
```

- [ ] **Step 6: Run test suite**

```bash
busted tests/
```

Expected: all pass.

- [ ] **Step 7: Commit**

```bash
git add lua/rooms/warrior/n_repeat.lua lua/rooms/warrior/ft_chain.lua \
  lua/rooms/warrior/visual_block.lua lua/rooms/warrior/ci_combo.lua \
  lua/rooms/warrior/change_chain.lua
git commit -m "feat: add 5 new warrior rooms"
```

---

## Task 17: New Ninja Rooms

**Files:**
- Create: `lua/rooms/ninja/global_macro.lua`
- Create: `lua/rooms/ninja/registers2.lua`
- Create: `lua/rooms/ninja/surround_obj.lua`
- Create: `lua/rooms/ninja/marks.lua`
- Create: `lua/rooms/ninja/substitute.lua`

- [ ] **Step 1: Create `lua/rooms/ninja/global_macro.lua`**

```lua
return {
  id = "ninja_global_macro",
  tier = "ninja",
  command = "qa … q + N@a",
  title = "Macro at Scale",
  description = "Record a macro into register a, then apply it to 7 more lines with 7@a",
  before_example = "foo\n|foo\nfoo",
  after_example = "bar\n|bar\nbar",
  usage_tip = "qa starts recording into 'a'. Do your edit. q stops. 7@a replays 7 times.",
  start_text = "foo\nfoo\nfoo\nfoo\nfoo\nfoo\nfoo\nfoo",
  target_text = "bar\nbar\nbar\nbar\nbar\nbar\nbar\nbar",
  base_xp = 110,
  time_limit = 60,
  optimal_keystrokes = { "q", "a", "c", "i", "w", "b", "a", "r", "\27", "j", "q", "7", "@", "a" },
}
```

- [ ] **Step 2: Create `lua/rooms/ninja/registers2.lua`**

```lua
return {
  id = "ninja_registers2",
  tier = "ninja",
  command = "\"ay / \"ap",
  title = "Named Register Workflow",
  description = "Yank into a named register with \"<reg>yy, paste with \"<reg>p",
  before_example = '"a yy → stores line. \"ap → pastes it.',
  after_example = "first line copied to end",
  usage_tip = '"ayy yanks into register a. "ap pastes from register a. Registers a-z are yours.',
  start_text = "alpha\nbeta\n[replace me]",
  target_text = "alpha\nbeta\nalpha",
  base_xp = 115,
  time_limit = 50,
  optimal_keystrokes = { '"', "a", "y", "y", "2", "j", "d", "d", '"', "a", "p" },
}
```

- [ ] **Step 3: Create `lua/rooms/ninja/surround_obj.lua`**

```lua
return {
  id = "ninja_surround_obj",
  tier = "ninja",
  command = "di\" / da( / ci{",
  title = "Text Object Deletion",
  description = "di<x> deletes inside delimiter. da<x> deletes including the delimiter itself.",
  before_example = 'fn("|hello")',
  after_example = 'fn("")',
  usage_tip = 'di" deletes inside quotes leaving them. da" deletes quotes too. ci" changes inside.',
  start_text = 'fn(compute("hello", (x + 1)))',
  target_text = 'fn(compute("hello", ()))',
  base_xp = 120,
  time_limit = 40,
  optimal_keystrokes = { "2", "f", "(", "d", "i", "(" },
}
```

- [ ] **Step 4: Create `lua/rooms/ninja/marks.lua`**

```lua
return {
  id = "ninja_marks",
  tier = "ninja",
  command = "m<a> / '<a> / `<a>",
  title = "Marks: Long-Range Jumps",
  description = "Set a mark with ma. Jump back to it with 'a (line) or `a (exact position).",
  before_example = "START|  →  mark →  navigate far  →  'a jumps back",
  after_example = "MARKED|  →  mark  →  navigate far  →  DONE",
  usage_tip = "ma sets mark 'a' at cursor. 'a jumps to that line from anywhere in the file.",
  start_text = "START\n\n\n\n\n\n\n\n\n\nEND",
  target_text = "MARKED\n\n\n\n\n\n\n\n\n\nDONE",
  base_xp = 110,
  time_limit = 60,
  optimal_keystrokes = { "m", "a", "9", "j", "c", "i", "w", "D", "O", "N", "E", "\27", "'", "a", "c", "i", "w", "M", "A", "R", "K", "E", "D", "\27" },
}
```

- [ ] **Step 5: Create `lua/rooms/ninja/substitute.lua`**

```lua
return {
  id = "ninja_substitute",
  tier = "ninja",
  command = ":%s/old/new/g",
  title = "Global Substitute",
  description = ":%s/pattern/replacement/g replaces all occurrences in the file",
  before_example = ":%s/hello/goodbye/g",
  after_example = "goodbye world …",
  usage_tip = "% means whole file. g flag means all occurrences per line. Omit g for first only.",
  start_text = "hello world\nhello vim\nhello neovim",
  target_text = "goodbye world\ngoodbye vim\ngoodbye neovim",
  base_xp = 105,
  time_limit = 35,
  optimal_keystrokes = { ":", "%", "s", "/", "h", "e", "l", "l", "o", "/", "g", "o", "o", "d", "b", "y", "e", "/", "g", "\r" },
}
```

- [ ] **Step 6: Run test suite**

```bash
busted tests/
```

Expected: all pass.

- [ ] **Step 7: Commit**

```bash
git add lua/rooms/ninja/global_macro.lua lua/rooms/ninja/registers2.lua \
  lua/rooms/ninja/surround_obj.lua lua/rooms/ninja/marks.lua \
  lua/rooms/ninja/substitute.lua
git commit -m "feat: add 5 new ninja rooms"
```

---

## Task 18: Final Integration Test

- [ ] **Step 1: Run full test suite**

```bash
busted tests/
```

Expected: all pass.

- [ ] **Step 2: Manual smoke test in Neovim**

Open Neovim and verify each of these works:

1. `:VimmerPlay` — map opens, beginner rooms show, boss shows as locked
2. `:VimmerPlay beginner_hjkl` — teach screen shows, play works, HUD has HP bar
3. `:VimmerPlay beginner_hjkl2` — count-motion room loads and plays
4. Complete a room with a `time_limit` set — verify timer appears in HUD, counts down
5. Press wrong keys repeatedly — combo resets, HP drops
6. Press 10+ correct keys — combo shows `x3` in HUD
7. Press 3 correct keys with HP < 100 — HP increments by 2
8. `:VimmerPlay beginner_boss` — boss teach screen shows 3 phases, play starts phase 1
9. Complete all 3 boss phases — verify phase banner flashes, then victory screen
10. Complete a timed room fast — verify power-up choice appears in results
11. Pick a power-up — verify next room's HUD shows the icon

- [ ] **Step 3: Commit any final fixes**

```bash
git add -p
git commit -m "fix: final integration fixes after smoke test"
```
