-- Beginner room: hjkl basic motion. Navigate to a char on line 2 and replace it.
return {
  id = "beginner_hjkl",
  tier = "beginner",
  command = "h / j / k / l",
  title = "Basic Motions: hjkl",
  description = "Move cursor left (h), down (j), up (k), right (l)",
  before_example = "local x = |1",
  after_example = "local x = |5",
  usage_tip = "Stay on home row. Never reach for arrow keys again.",
  filetype = "lua",
  cursor_start = { row = 1, col = 1 },
  goal = "Change the `2` on line 2 to `5`.",
  start_text = [[
local one = 1
local two = 2
local three = 3]],
  target_text = [[
local one = 1
local two = 5
local three = 3]],
  base_xp = 30,
  time_limit = 60,
  optimal_keystrokes = { "j", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "l", "r", "5" },
  optimal_keystrokes_alternates = {
    { "j", "$", "r", "5" },
  },
}
