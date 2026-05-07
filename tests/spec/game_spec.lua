dofile(debug.getinfo(1, "S").source:gsub("@", ""):match("^(.*)/[^/]+$") .. "/helpers.lua")
local game = require("the-vimmer.game")

local function make_room(overrides)
  local r = { id = "test", base_xp = 50, optimal_keystrokes = { "w", "b" } }
  for k, v in pairs(overrides or {}) do r[k] = v end
  return r
end

describe("game state machine", function()
  local g

  before_each(function() g = game.new() end)

  it("starts in idle state", function()
    assert.equals("idle", g.state)
  end)

  it("idle -> teaching on start_room", function()
    g:start_room(make_room())
    assert.equals("teaching", g.state)
  end)

  it("teaching -> playing on begin_play, HP reset to 100", function()
    g:start_room(make_room()); g:begin_play()
    assert.equals("playing", g.state)
    assert.equals(100, g.hp)
  end)

  it("playing -> results on complete_room", function()
    g:start_room(make_room()); g:begin_play(); g:complete_room()
    assert.equals("results", g.state)
  end)

  it("results -> idle on dismiss_results", function()
    g:start_room(make_room()); g:begin_play(); g:complete_room()
    g:dismiss_results()
    assert.equals("idle", g.state)
  end)
end)

describe("game HP tracking", function()
  local g

  before_each(function()
    g = game.new()
    g:start_room(make_room()); g:begin_play()
  end)

  it("starts at 100 HP", function()
    assert.equals(100, g.hp)
  end)

  it("optimal keystroke does not drain HP", function()
    g:register_key("w")
    assert.equals(100, g.hp)
  end)

  it("non-optimal keystroke drains 5 HP", function()
    g:register_key("x")
    assert.equals(95, g.hp)
  end)

  it("HP never goes below 0", function()
    for _ = 1, 30 do g:register_key("x") end
    assert.equals(0, g.hp)
  end)

  it("is_dead returns true at 0 HP", function()
    for _ = 1, 20 do g:register_key("x") end
    assert.is_true(g:is_dead())
  end)

  it("is_dead returns false above 0 HP", function()
    g:register_key("x")
    assert.is_false(g:is_dead())
  end)

  it("register_key is a no-op outside playing state", function()
    -- Switch to teaching state and verify HP is not drained
    g:start_room(make_room())   -- resets state to teaching
    g.state = "teaching"
    g.hp = 100
    g:register_key("x")
    assert.equals(100, g.hp)
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
  it("is set after complete_room", function()
    local g = game.new()
    g:start_room(make_room()); g:begin_play()
    g:complete_room()
    -- calculate_xp(50, 100, 0) = base(50) + hp_bonus(floor(100/100*50)=50) = 100
    assert.equals(100, g.last_xp)
  end)

  it("HP drained before complete_room affects last_xp", function()
    local g = game.new()
    g:start_room(make_room()); g:begin_play()
    -- 5 non-optimal keystrokes * 5 HP each = 25 HP drained, 75 HP remaining
    for _ = 1, 5 do g:register_key("x") end
    assert.equals(75, g.hp)
    g:complete_room()
    -- calculate_xp(50, 75, 0) = base(50) + hp_bonus(floor(75/100*50)=37) = 87
    local progress = require("the-vimmer.progress")
    local expected = progress.calculate_xp(50, 75, 0)
    assert.equals(expected, g.last_xp)
  end)
end)

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

  it("wrong key resets correct_streak, no regen on 3rd", function()
    g:register_key("w"); g:register_key("w"); g:register_key("x")
    g:register_key("w"); g:register_key("w")
    assert.equals(88 - 5, g.hp)
  end)
end)

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
    assert.equals(0, #g.power_ups)
  end)

  it("hp_restore adds 30 HP capped at 100", function()
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

  it("_phase_optimal returns phase 1 optimal keys", function()
    assert.same({"w"}, g:_phase_optimal())
  end)

  it("_phase_optimal returns phase 2 keys after advance", function()
    g:advance_boss_phase()
    assert.same({"w"}, g:_phase_optimal())
  end)
end)

describe("game.complete_room with combo_mult", function()
  it("applies combo_mult to XP", function()
    local g = game.new()
    g:start_room(make_room({ base_xp = 50 })); g:begin_play()
    g.combo_mult = 2
    g:complete_room()
    local progress = require("the-vimmer.progress")
    assert.equals(progress.calculate_xp(50, 100, 0, 2, false), g.last_xp)
  end)

  it("double_xp power-up doubles XP and is consumed", function()
    local g = game.new()
    g:start_room(make_room({ base_xp = 50 })); g:begin_play()
    g.power_ups = { { type = "double_xp" } }
    g:complete_room()
    local progress = require("the-vimmer.progress")
    assert.equals(progress.calculate_xp(50, 100, 0, 1, true), g.last_xp)
    assert.equals(0, #g.power_ups)
  end)
end)
