dofile(debug.getinfo(1, "S").source:gsub("@", ""):match("^(.*)/[^/]+$") .. "/helpers.lua")
local learning = require("the-vimmer.learning")
local function room(id, boss) return { id = id, tier = id:match("^(.-)_"), is_boss = boss } end

describe("learning path", function()
  it("starts with motions instead of alphabetical filenames", function()
    local list = { room("beginner_w_motion"), room("beginner_replace_char"), room("beginner_hjkl"), room("beginner_boss", true) }
    learning.sort(list, "beginner")
    assert.equals("beginner_hjkl", list[1].id)
    assert.equals("beginner_boss", list[#list].id)
  end)
  it("keeps external rooms and orders them before the boss", function()
    local list = { room("beginner_boss", true), room("beginner_z_extra"), room("beginner_a_extra"), room("beginner_hjkl") }
    learning.sort(list, "beginner")
    assert.equals("beginner_a_extra", list[2].id)
    assert.equals("beginner_z_extra", list[3].id)
    assert.equals("Extra adventures", learning.group_for(list[2]))
  end)
  it("recommends the next uncleared skill without opening locked tiers", function()
    local by_tier = { beginner = { room("beginner_hjkl"), room("beginner_replace_char"), room("beginner_boss", true) }, warrior = { room("warrior_f_motion") } }
    local p = { cleared = { beginner_hjkl = true } }
    assert.equals("beginner_replace_char", learning.next_room(p, by_tier).id)
    p.cleared.beginner_replace_char = true
    assert.equals("beginner_boss", learning.next_room(p, by_tier).id)
    p.cleared.beginner_boss = true
    assert.equals("warrior_f_motion", learning.next_room(p, by_tier).id)
  end)
  it("returns no recommendation after every available room is cleared", function()
    assert.is_nil(learning.next_room({ cleared = { beginner_hjkl = true } }, { beginner = { room("beginner_hjkl") } }))
  end)
end)
