-- Beginner room: Nj / Nl count-prefixed motions. Jump down with 4j and edit.
return {
  id = "beginner_hjkl2",
  tier = "beginner",
  command = "Nj / Nk / Nl / Nh",
  title = "Count Motions",
  description = "Prefix hjkl with a number to move multiple steps at once",
  before_example = "line 1 |TODO",
  after_example = "line 1 |DONE",
  usage_tip = "3j moves 3 lines down. 5l moves 5 chars right. No arrow keys.",
  filetype = "lua",
  cursor_start = { row = 1, col = 1 },
  goal = "Change the `0` on line 5 to `9`.",
  start_text = [[
local counters = {
  alpha = 1,
  beta  = 2,
  gamma = 3,
  delta = 0,
}]],
  target_text = [[
local counters = {
  alpha = 1,
  beta  = 2,
  gamma = 3,
  delta = 9,
}]],
  base_xp = 40,
  time_limit = 45,
  optimal_keystrokes = { "4", "j", "1", "0", "l", "r", "9" },
  optimal_keystrokes_alternates = {
    { "j", "j", "j", "j", "$", "h", "r", "9" },
  },
}
