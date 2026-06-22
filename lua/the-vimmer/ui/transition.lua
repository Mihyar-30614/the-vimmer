-- Full-screen flashes between major UI screens (teach → play → results/death).
local M = {}
local float = require("the-vimmer.ui.float")

local SEQUENCES = {
  enter_play = { { "VimmerXP", 70 }, { nil, 40 } },
  victory    = { { "VimmerWin", 90 }, { "VimmerCrit", 60 }, { nil, 40 } },
  defeat     = { { "VimmerDamage", 90 }, { "VimmerDeath", 70 }, { nil, 50 } },
}

function M.run(name, callback)
  float.multi_overlay_flash(SEQUENCES[name] or SEQUENCES.enter_play, callback)
end

return M
