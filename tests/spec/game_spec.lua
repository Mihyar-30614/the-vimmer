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
    g:start_room(make_room()); g:begin_play(); g:complete_room(100)
    assert.equals("results", g.state)
  end)

  it("results -> idle on dismiss_results", function()
    g:start_room(make_room()); g:begin_play(); g:complete_room(100)
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
end)

describe("game streak", function()
  it("increments streak on dismiss_results", function()
    local g = game.new()
    g:start_room(make_room()); g:begin_play(); g:complete_room(100)
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
    g:complete_room(100)
    -- calculate_xp(50, 100, 0) = base(50) + hp_bonus(floor(100/100*50)=50) = 100
    assert.equals(100, g.last_xp)
  end)
end)
