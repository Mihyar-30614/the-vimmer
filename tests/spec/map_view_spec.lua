dofile(debug.getinfo(1, "S").source:gsub("@", ""):match("^(.*)/[^/]+$") .. "/helpers.lua")
-- map.lua requires float.lua, which calls vim.api at require time. build_view
-- itself is api-free, so a no-op api stub is enough to load the module here.
_G.vim.api = _G.vim.api or { nvim_create_namespace = function() return 0 end }
local map = require("the-vimmer.ui.map")

-- Minimal mock: beginner tier (always unlocked) with 2 regular rooms + boss.
local function fixture()
  return {
    beginner = {
      { id = "beginner_a", title = "Room A" },
      { id = "beginner_b", title = "Room B" },
      { id = "beginner_boss", title = "Beginner Boss", is_boss = true },
    },
  }
end

local function progress(cleared)
  return { total_xp = 0, streak = 0, cleared = cleared or {} }
end

local function nav_kinds(nav)
  local out = {}
  for _, item in ipairs(nav) do out[#out + 1] = item.kind end
  return out
end

describe("map.build_view fold behavior", function()
  it("expanded tier emits a tier item followed by its room items", function()
    local _, _, nav = map._build_view({ beginner = false }, progress(), fixture(), 60)
    -- boss is locked (0% cleared) so it is rendered but NOT in nav.
    assert.same({ "tier", "room", "room" }, nav_kinds(nav))
    assert.equal("beginner", nav[1].tier)
    assert.equal("beginner_a", nav[2].room.id)
  end)

  it("folded tier emits only its tier item", function()
    local _, _, nav = map._build_view({ beginner = true }, progress(), fixture(), 60)
    assert.same({ "tier" }, nav_kinds(nav))
  end)

  it("cleared regular rooms are still navigable", function()
    local prog = progress({ beginner_a = true })
    local _, _, nav = map._build_view({ beginner = false }, prog, fixture(), 60)
    -- both rooms present regardless of cleared state
    assert.same({ "tier", "room", "room" }, nav_kinds(nav))
  end)

  it("unlocked boss is navigable", function()
    -- both regular rooms cleared -> boss unlocked (>=80%)
    local prog = progress({ beginner_a = true, beginner_b = true })
    local _, _, nav = map._build_view({ beginner = false }, prog, fixture(), 60)
    assert.same({ "tier", "room", "room", "room" }, nav_kinds(nav))
    assert.equal("beginner_boss", nav[4].room.id)
  end)

  it("folded header shows the closed marker, expanded shows open", function()
    local folded_lines = select(1, map._build_view({ beginner = true }, progress(), fixture(), 60))
    local open_lines = select(1, map._build_view({ beginner = false }, progress(), fixture(), 60))
    local function has(lines, glyph)
      for _, l in ipairs(lines) do if l:find(glyph, 1, true) then return true end end
      return false
    end
    assert.is_true(has(folded_lines, "▸"))
    assert.is_true(has(open_lines, "▾"))
  end)
end)

describe("map.tier_fully_cleared", function()
  it("false until every regular room and the boss are cleared", function()
    local rooms = { { id = "beginner_a" }, { id = "beginner_b" } }
    local boss = { id = "beginner_boss", is_boss = true }
    assert.is_false(map._tier_fully_cleared(rooms, boss, { beginner_a = true }))
    assert.is_false(map._tier_fully_cleared(rooms, boss,
      { beginner_a = true, beginner_b = true }))
    assert.is_true(map._tier_fully_cleared(rooms, boss,
      { beginner_a = true, beginner_b = true, beginner_boss = true }))
  end)
end)
