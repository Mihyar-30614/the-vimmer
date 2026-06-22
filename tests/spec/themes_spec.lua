dofile(debug.getinfo(1, "S").source:gsub("@", ""):match("^(.*)/[^/]+$") .. "/helpers.lua")
local themes = require("the-vimmer.themes")

describe("themes.colors", function()
  it("returns the dracula palette by default", function()
    local c = themes.colors({})
    assert.equals("#f1fa8c", c.xp)
    assert.equals("#50fa7b", c.hp_high)
    assert.equals("#ff5555", c.hp_low)
    assert.equals("#ffffff", c.title)
  end)

  it("treats an unknown theme name as dracula", function()
    local c = themes.colors({ theme = "nope" })
    assert.equals("#f1fa8c", c.xp)
  end)

  it("merges a custom color table over dracula", function()
    local c = themes.colors({ theme = { xp = "#123456", boss = "#abcdef" } })
    assert.equals("#123456", c.xp)
    assert.equals("#abcdef", c.boss)
    -- untouched roles keep dracula
    assert.equals("#ffffff", c.title)
  end)

  it("applies the colorblind overlay on top of the chosen theme", function()
    local base = themes.colors({})
    local cb = themes.colors({ colorblind = true })
    assert.equals("#56b4e9", cb.hp_high)
    assert.equals("#e69f00", cb.hp_low)
    assert.equals("#f0e442", cb.xp)
    assert.equals("#56b4e9", cb.cleared)
    -- a role outside the overlay is unchanged from base
    assert.equals(base.title, cb.title)
  end)

  it("colorblind overlay wins over a custom theme for sensitive roles", function()
    local c = themes.colors({ theme = { hp_high = "#000000" }, colorblind = true })
    assert.equals("#56b4e9", c.hp_high)
  end)

  it("does not mutate the shared dracula table between calls", function()
    themes.colors({ theme = { xp = "#111111" } })
    local c = themes.colors({})
    assert.equals("#f1fa8c", c.xp)
  end)
end)

describe("themes.resolve_auto", function()
  it("substitutes colors the colorscheme provides", function()
    local reader = function(group)
      if group == "Function" then return "#aa0000" end
      if group == "String" then return "#00bb00" end
      return nil
    end
    local c = themes.resolve_auto(reader)
    assert.equals("#aa0000", c.xp)       -- xp samples Function
    assert.equals("#00bb00", c.cleared)  -- cleared samples String
  end)

  it("falls back to dracula for roles the colorscheme lacks", function()
    local c = themes.resolve_auto(function() return nil end)
    assert.equals("#f1fa8c", c.xp)
    assert.equals("#ffffff", c.title)
  end)

  it("is reachable via colors({ theme = 'auto' })", function()
    local c = themes.colors({ theme = "auto", reader = function() return nil end })
    assert.equals("#f1fa8c", c.xp)
  end)
end)

describe("themes.build_groups", function()
  it("maps friendly colors onto every Vimmer highlight group", function()
    local groups = themes.build_groups(themes.colors({}))
    assert.equals("#f1fa8c", groups.VimmerXP.fg)
    assert.is_true(groups.VimmerXP.bold)
    assert.equals("#50fa7b", groups.VimmerHP_high.fg)
    assert.equals("#50fa7b", groups.VimmerWin.bg)
    assert.equals("#282a36", groups.VimmerWin.fg)
    assert.equals("#ff79c6", groups.VimmerBoss.fg)
    assert.equals("#44475a", groups.VimmerPhase.bg)
  end)

  it("includes the static reverse Selected group", function()
    local groups = themes.build_groups(themes.colors({}))
    assert.is_true(groups.VimmerSelected.reverse)
  end)

  it("covers exactly the groups highlights.setup applied", function()
    local groups = themes.build_groups(themes.colors({}))
    local expected = {
      "VimmerTitle", "VimmerTierBeginner", "VimmerTierWarrior", "VimmerTierNinja",
      "VimmerTierGrandmaster", "VimmerCleared", "VimmerLocked", "VimmerSelected",
      "VimmerXP", "VimmerHP_high", "VimmerHP_mid", "VimmerHP_low", "VimmerWin",
      "VimmerDeath", "VimmerCommand", "VimmerExample", "VimmerTimerOk",
      "VimmerTimerWarn", "VimmerTimerDanger", "VimmerBoss", "VimmerPhase",
      "VimmerDamage", "VimmerCrit", "VimmerTeachTip", "VimmerTeachFoot",
    }
    for _, g in ipairs(expected) do
      assert.is_table(groups[g], "missing group " .. g)
    end
    local count = 0
    for _ in pairs(groups) do count = count + 1 end
    assert.equals(#expected, count)
  end)
end)
