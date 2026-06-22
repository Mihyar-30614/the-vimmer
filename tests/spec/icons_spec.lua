dofile(debug.getinfo(1, "S").source:gsub("@", ""):match("^(.*)/[^/]+$") .. "/helpers.lua")
local icons = require("the-vimmer.ui.icons")

describe("ui.icons", function()
  after_each(function()
    package.loaded["the-vimmer"] = nil
  end)

  it("returns unicode glyphs by default", function()
    assert.equal("♥", icons.get("hp"))
    assert.equal("▶", icons.get("cursor"))
  end)

  it("returns ascii glyphs when configured", function()
    package.loaded["the-vimmer"] = { config = { icons = "ascii" } }
    assert.equal("HP", icons.get("hp"))
    assert.equal(">", icons.get("cursor"))
  end)
end)
