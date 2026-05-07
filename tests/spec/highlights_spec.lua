dofile(debug.getinfo(1, "S").source:gsub("@", ""):match("^(.*)/[^/]+$") .. "/helpers.lua")
local hl = require("the-vimmer.highlights")

describe("highlights.hp_group", function()
  it("returns VimmerHP_high above 60", function()
    assert.equals("VimmerHP_high", hl.hp_group(100))
    assert.equals("VimmerHP_high", hl.hp_group(61))
  end)

  it("returns VimmerHP_mid between 31 and 60 inclusive", function()
    assert.equals("VimmerHP_mid", hl.hp_group(60))
    assert.equals("VimmerHP_mid", hl.hp_group(31))
  end)

  it("returns VimmerHP_low at 30 and below", function()
    assert.equals("VimmerHP_low", hl.hp_group(30))
    assert.equals("VimmerHP_low", hl.hp_group(0))
  end)
end)
