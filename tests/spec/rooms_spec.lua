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

describe("rooms.all_tiers", function()
  it("returns three tiers in order", function()
    local tiers = rooms.all_tiers()
    assert.equals("beginner", tiers[1])
    assert.equals("warrior", tiers[2])
    assert.equals("ninja", tiers[3])
  end)
end)
