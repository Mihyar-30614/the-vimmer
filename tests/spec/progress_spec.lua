dofile(debug.getinfo(1, "S").source:gsub("@", ""):match("^(.*)/[^/]+$") .. "/helpers.lua")
local progress = require("the-vimmer.progress")

describe("progress.calculate_xp", function()
  it("full HP no streak = base + full hp bonus", function()
    assert.equals(100, progress.calculate_xp(50, 100, 0))
  end)

  it("half HP no streak = base + half hp bonus", function()
    assert.equals(75, progress.calculate_xp(50, 50, 0))
  end)

  it("zero HP no streak = base only", function()
    assert.equals(50, progress.calculate_xp(50, 0, 0))
  end)

  it("adds 50% streak bonus when streak >= 3", function()
    -- subtotal = 50+50 = 100, streak_bonus = 50 → 150
    assert.equals(150, progress.calculate_xp(50, 100, 3))
  end)

  it("no streak bonus when streak < 3", function()
    assert.equals(100, progress.calculate_xp(50, 100, 2))
  end)
end)

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
    cleared["beginner_boss"] = true
    assert.is_false(progress.is_boss_unlocked("beginner", cleared, 10))
  end)
end)

describe("progress.save and progress.load", function()
  local tmp

  before_each(function()
    tmp = os.tmpname() .. ".json"
  end)

  after_each(function()
    os.remove(tmp)
  end)

  it("round-trips progress data", function()
    local data = { total_xp = 120, cleared = { beginner_hjkl = true }, streak = 2 }
    progress.save(data, tmp)
    local loaded = progress.load(tmp)
    assert.equals(120, loaded.total_xp)
    assert.is_true(loaded.cleared.beginner_hjkl)
    assert.equals(2, loaded.streak)
  end)

  it("returns default state on missing file", function()
    local loaded = progress.load("/nonexistent/path/no.json")
    assert.equals(0, loaded.total_xp)
    assert.same({}, loaded.cleared)
    assert.equals(0, loaded.streak)
  end)

  it("returns default state on corrupt file", function()
    local f = io.open(tmp, "w"); f:write("{{not json}}"); f:close()
    local loaded = progress.load(tmp)
    assert.equals(0, loaded.total_xp)
  end)
end)

describe("progress.reset_data", function()
  it("returns clean default state", function()
    local state = progress.reset_data()
    assert.equals(0, state.total_xp)
    assert.same({}, state.cleared)
    assert.equals(0, state.streak)
  end)
end)

describe("progress.reset", function()
  it("wipes progress and load returns default state", function()
    local tmp = os.tmpname() .. ".json"
    local data = { total_xp = 500, cleared = { beginner_hjkl = true }, streak = 4 }
    progress.save(data, tmp)
    progress.reset(tmp)
    local loaded = progress.load(tmp)
    assert.equals(0, loaded.total_xp)
    assert.same({}, loaded.cleared)
    assert.equals(0, loaded.streak)
    os.remove(tmp)
  end)
end)

describe("progress.refresh_mutator_unlocks", function()
  it("unlocks iron when XP crosses threshold", function()
    local prog = { total_xp = progress.MUTATOR_UNLOCK_XP.iron, unlocked_mutators = {} }
    progress.refresh_mutator_unlocks(prog)
    assert.is_true(prog.unlocked_mutators.iron)
  end)
end)

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
