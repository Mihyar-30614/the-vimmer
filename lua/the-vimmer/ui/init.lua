-- Facade for the the-vimmer.ui submodules.
--
-- IMPORTANT: submodules must NOT top-level-require this file. Cross-screen
-- calls (e.g. teach → key_replay, death → key_replay) must use lazy
-- `require("the-vimmer.ui").open_<name>(...)` inside function bodies. A
-- top-level require here would trigger a circular load — init.lua is still
-- mid-require when the submodule loads, so the submodule would see an
-- empty table.
local M = {}

local function merge(name)
  for k, v in pairs(require("the-vimmer.ui." .. name)) do
    M[k] = v
  end
end

merge("key_replay")
merge("map")
merge("progress")
merge("teach")
merge("play")
merge("results")
merge("death")

return M
