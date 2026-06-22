-- Ninja room: "_dd. Discard a line into the black hole so the yank register survives.
return {
  id = "ninja_black_hole",
  tier = "ninja",
  command = "\"_d / \"_dd",
  title = "Black Hole Register: \"_",
  description = "Deleting with \"_ discards text without overwriting the unnamed yank register.",
  usage_tip = "\"_ is the black hole — anything deleted into it is gone. Use \"_dd to delete a line without losing what you yanked.",
  efficiency_hint = "Delete to the black-hole register to discard without losing your yank.",
  before_example = "keep|\njunk\nkeep",
  after_example = "keep|\nkeep",
  filetype = "lua",
  cursor_start = { row = 1, col = 1 },
  time_limit = 70,
  goal = "Yank line 1, delete line 3 (bad) into the black hole, paste yank at end.",
  start_text = [[
local good = compute()
local x = 1
local bad = "remove me"
local y = 2]],
  target_text = [[
local good = compute()
local x = 1
local y = 2
local good = compute()]],
  base_xp = 125,
  optimal_keystrokes = { "y", "y", "j", "j", "\"", "_", "d", "d", "G", "p" },
  optimal_keystrokes_alternates = {
    { "y", "y", "3", "G", "\"", "_", "d", "d", "G", "p" },
  },
}
