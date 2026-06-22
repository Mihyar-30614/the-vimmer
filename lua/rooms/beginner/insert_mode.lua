-- Beginner room: i/a/o. Open a new line inside a table and type a key.
return {
  id = "beginner_insert_mode",
  tier = "beginner",
  command = "i / a / o",
  title = "Insert Mode: i, a, o",
  description = "Enter insert mode: before cursor (i), after cursor (a), new line below (o)",
  before_example = "alpha = 1,|",
  after_example = "alpha = 1,\n  beta = 2,|",
  usage_tip = "i inserts BEFORE cursor. Move to the gap, press i, type, then <Esc>.",
  efficiency_hint = "o opens a new line below in a single stroke.",
  filetype = "lua",
  cursor_start = { row = 2, col = 1 },
  goal = "Add a new line `  beta = 2,` after `alpha`.",
  start_text = [[
local M = {
  alpha = 1,
}]],
  target_text = [[
local M = {
  alpha = 1,
  beta = 2,
}]],
  base_xp = 50,
  time_limit = 60,
  optimal_keystrokes = { "o", "b", "e", "t", "a", " ", "=", " ", "2", ",", "\27" },
}
