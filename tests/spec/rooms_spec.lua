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

describe("rooms.validate optional filetype", function()
  local base = {
    id = "t", tier = "beginner", command = "w",
    title = "T", description = "D",
    before_example = "a", after_example = "b",
    usage_tip = "tip", start_text = "x", target_text = "y",
    base_xp = 10, optimal_keystrokes = { "w" },
  }
  local function clone() local r = {}; for k, v in pairs(base) do r[k] = v end; return r end

  it("accepts room without filetype", function()
    assert.is_true(rooms.validate(clone()))
  end)

  it("accepts room with string filetype", function()
    local r = clone(); r.filetype = "typescript"
    assert.is_true(rooms.validate(r))
  end)

  it("rejects room with non-string filetype", function()
    local r = clone(); r.filetype = 123
    assert.is_false(rooms.validate(r))
  end)
end)

describe("rooms.validate optional cursor_start", function()
  local base = {
    id = "t", tier = "beginner", command = "w",
    title = "T", description = "D",
    before_example = "a", after_example = "b",
    usage_tip = "tip", start_text = "x", target_text = "y",
    base_xp = 10, optimal_keystrokes = { "w" },
  }
  local function clone() local r = {}; for k, v in pairs(base) do r[k] = v end; return r end

  it("accepts room without cursor_start", function()
    assert.is_true(rooms.validate(clone()))
  end)

  it("accepts room with valid cursor_start", function()
    local r = clone(); r.cursor_start = { row = 3, col = 5 }
    assert.is_true(rooms.validate(r))
  end)

  it("rejects cursor_start with non-table value", function()
    local r = clone(); r.cursor_start = "1,1"
    assert.is_false(rooms.validate(r))
  end)

  it("rejects cursor_start with missing row", function()
    local r = clone(); r.cursor_start = { col = 1 }
    assert.is_false(rooms.validate(r))
  end)

  it("rejects cursor_start with non-integer row", function()
    local r = clone(); r.cursor_start = { row = 1.5, col = 1 }
    assert.is_false(rooms.validate(r))
  end)

  it("rejects cursor_start with row < 1", function()
    local r = clone(); r.cursor_start = { row = 0, col = 1 }
    assert.is_false(rooms.validate(r))
  end)

  it("rejects cursor_start with col < 1", function()
    local r = clone(); r.cursor_start = { row = 1, col = 0 }
    assert.is_false(rooms.validate(r))
  end)
end)

describe("rooms.validate optional goal", function()
  local base = {
    id = "t", tier = "beginner", command = "w",
    title = "T", description = "D",
    before_example = "a", after_example = "b",
    usage_tip = "tip", start_text = "x", target_text = "y",
    base_xp = 10, optimal_keystrokes = { "w" },
  }
  local function clone() local r = {}; for k, v in pairs(base) do r[k] = v end; return r end

  it("accepts room without goal", function()
    assert.is_true(rooms.validate(clone()))
  end)

  it("accepts room with string goal", function()
    local r = clone(); r.goal = "Rename param"
    assert.is_true(rooms.validate(r))
  end)

  it("rejects room with non-string goal", function()
    local r = clone(); r.goal = { "bad" }
    assert.is_false(rooms.validate(r))
  end)
end)

describe("rooms.validate boss phase optional fields", function()
  local base_boss = {
    id = "tb", tier = "warrior", is_boss = true,
    command = "X", title = "B", description = "D",
    usage_tip = "tip", base_xp = 300, time_limit = 100,
    phases = {
      { start_text = "a", target_text = "b", optimal_keystrokes = { "x" }, tip = "p1" },
    },
  }
  local function clone()
    local r = {}; for k, v in pairs(base_boss) do r[k] = v end
    r.phases = { {} }
    for k, v in pairs(base_boss.phases[1]) do r.phases[1][k] = v end
    return r
  end

  it("accepts boss with valid per-phase filetype/cursor_start/goal", function()
    local r = clone()
    r.phases[1].filetype = "lua"
    r.phases[1].cursor_start = { row = 1, col = 1 }
    r.phases[1].goal = "do the thing"
    assert.is_true(rooms.validate(r))
  end)

  it("rejects boss with malformed per-phase cursor_start", function()
    local r = clone()
    r.phases[1].cursor_start = { row = 0, col = 1 }
    assert.is_false(rooms.validate(r))
  end)

  it("rejects boss with non-string per-phase filetype", function()
    local r = clone()
    r.phases[1].filetype = 7
    assert.is_false(rooms.validate(r))
  end)
end)

describe("rooms.phase_view", function()
  it("returns defaults when fields absent", function()
    local v = rooms.phase_view({
      start_text = "x", target_text = "y",
      optimal_keystrokes = { "w" },
    })
    assert.equals("", v.filetype)
    assert.same({ row = 1, col = 1 }, v.cursor_start)
    assert.is_nil(v.goal)
    assert.equals("x", v.start_text)
    assert.equals("y", v.target_text)
  end)

  it("passes through provided values", function()
    local v = rooms.phase_view({
      start_text = "x", target_text = "y",
      optimal_keystrokes = { "w" },
      filetype = "lua",
      cursor_start = { row = 4, col = 2 },
      goal = "G",
      bo = { shiftwidth = 4 },
      optimal_keystrokes_alternates = { { "a" } },
    })
    assert.equals("lua", v.filetype)
    assert.same({ row = 4, col = 2 }, v.cursor_start)
    assert.equals("G", v.goal)
    assert.same({ shiftwidth = 4 }, v.bo)
    assert.same({ { "a" } }, v.optimal_keystrokes_alternates)
  end)
end)
