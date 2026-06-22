dofile(debug.getinfo(1, "S").source:gsub("@", ""):match("^(.*)/[^/]+$") .. "/helpers.lua")
local anim = require("the-vimmer.ui.anim")

describe("anim.lerp", function()
  it("interpolates endpoints and midpoint", function()
    assert.equals(0, anim.lerp(0, 10, 0))
    assert.equals(10, anim.lerp(0, 10, 1))
    assert.equals(5, anim.lerp(0, 10, 0.5))
  end)
end)

describe("anim.ease_out_quad", function()
  it("pins 0 and 1", function()
    assert.equals(0, anim.ease_out_quad(0))
    assert.equals(1, anim.ease_out_quad(1))
  end)
  it("is ahead of linear in the first half (decelerating)", function()
    assert.is_true(anim.ease_out_quad(0.5) > 0.5)
  end)
end)

describe("anim.count_frames", function()
  it("returns exactly `steps` frames ending on `to`", function()
    local f = anim.count_frames(0, 120, 10)
    assert.equals(10, #f)
    assert.equals(120, f[#f])
  end)

  it("rises monotonically toward the target", function()
    local f = anim.count_frames(0, 100, 20)
    for i = 2, #f do
      assert.is_true(f[i] >= f[i - 1])
    end
  end)

  it("returns integer values", function()
    local f = anim.count_frames(0, 7, 5)
    for _, v in ipairs(f) do
      assert.equals(v, math.floor(v))
    end
  end)

  it("handles from == to", function()
    local f = anim.count_frames(50, 50, 4)
    for _, v in ipairs(f) do assert.equals(50, v) end
  end)

  it("degenerates to a single final frame when steps < 1", function()
    assert.same({ 99 }, anim.count_frames(0, 99, 0))
  end)
end)

describe("anim.bar", function()
  it("renders a nearest-rounded fill by default", function()
    assert.equals("█████░░░░░", anim.bar(50, 100, 10))
  end)

  it("supports ceil rounding to match the HUD HP bar", function()
    -- 84/100 over 10 cells: ceil(8.4) = 9 filled
    assert.equals("█████████░", anim.bar(84, 100, 10, { round = "ceil" }))
  end)

  it("clamps over and under range", function()
    assert.equals("██████", anim.bar(999, 100, 6))
    assert.equals("░░░░░░", anim.bar(-5, 100, 6))
  end)

  it("renders all-empty when max is zero", function()
    assert.equals("░░░░", anim.bar(3, 0, 4))
  end)

  it("honors custom fill/empty glyphs", function()
    assert.equals("##--", anim.bar(50, 100, 4, { fill = "#", empty = "-" }))
  end)
end)

describe("anim.burst_frames", function()
  it("produces the requested number of centered frames of fixed width", function()
    local frames = anim.burst_frames(5, 11)
    assert.equals(5, #frames)
    for _, line in ipairs(frames) do
      assert.equals(11, #line)
    end
  end)
end)
