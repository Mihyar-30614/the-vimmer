dofile(debug.getinfo(1, "S").source:gsub("@", ""):match("^(.*)/[^/]+$") .. "/helpers.lua")
local rooms = require("the-vimmer.rooms")

describe("rooms.validate", function()
  local valid_room = {
    id = "test_room", tier = "beginner", command = "w",
    title = "Test", description = "Desc",
    before_example = "|before", after_example = "after|",
    usage_tip = "tip", start_text = "start", target_text = "target",
    base_xp = 50, optimal_keystrokes = { "w" },
  }

  it("accepts a valid room", function()
    assert.is_true(rooms.validate(valid_room))
  end)

  it("rejects room missing id", function()
    local r = {}
    for k, v in pairs(valid_room) do r[k] = v end
    r.id = nil
    assert.is_false(rooms.validate(r))
  end)

  it("rejects room missing optimal_keystrokes", function()
    local r = {}
    for k, v in pairs(valid_room) do r[k] = v end
    r.optimal_keystrokes = nil
    assert.is_false(rooms.validate(r))
  end)

  it("rejects invalid optimal_keystrokes_alternates", function()
    local r = {}
    for k, v in pairs(valid_room) do r[k] = v end
    r.optimal_keystrokes_alternates = "bad"
    assert.is_false(rooms.validate(r))
  end)
end)

describe("rooms.acceptable_key_sequences", function()
  it("returns primary plus alternates", function()
    local seqs = rooms.acceptable_key_sequences({
      optimal_keystrokes = { "w", "c", "i", "w" },
      optimal_keystrokes_alternates = { { "w", "c", "a", "w" } },
    })
    assert.equals(2, #seqs)
    assert.same({ "w", "c", "i", "w" }, seqs[1])
    assert.same({ "w", "c", "a", "w" }, seqs[2])
  end)
end)

describe("rooms.load_tier", function()
  it("loads rooms from beginner tier", function()
    local loaded = rooms.load_tier("beginner")
    assert.is_true(#loaded > 0)
  end)

  it("loaded rooms have correct tier", function()
    local loaded = rooms.load_tier("beginner")
    for _, r in ipairs(loaded) do
      assert.equals("beginner", r.tier)
    end
  end)

  it("returns empty table for nonexistent tier", function()
    local loaded = rooms.load_tier("nonexistent")
    assert.same({}, loaded)
  end)
end)

describe("rooms.get_room", function()
  it("returns room by id", function()
    local room = rooms.get_room("beginner_hjkl")
    assert.is_not_nil(room)
    assert.equals("beginner_hjkl", room.id)
  end)

  it("returns nil for unknown id", function()
    assert.is_nil(rooms.get_room("does_not_exist"))
  end)
end)

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

describe("rooms.all_tiers", function()
  it("returns three tiers in order", function()
    local tiers = rooms.all_tiers()
    assert.equals("beginner", tiers[1])
    assert.equals("warrior", tiers[2])
    assert.equals("ninja", tiers[3])
  end)
end)

describe("rooms.load_tier cache", function()
  before_each(function()
    if rooms.clear_cache then rooms.clear_cache() end
  end)

  it("returns the same table on repeat calls", function()
    local a = rooms.load_tier("beginner")
    local b = rooms.load_tier("beginner")
    assert.is_true(a == b, "expected identical table reference on second call")
  end)

  it("clear_cache forces a fresh load (different table identity)", function()
    local a = rooms.load_tier("beginner")
    rooms.clear_cache()
    local b = rooms.load_tier("beginner")
    assert.is_false(a == b, "expected fresh table after clear_cache")
  end)
end)

describe("rooms.load_tier picks up new content rooms", function()
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
