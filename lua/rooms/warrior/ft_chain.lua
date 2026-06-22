-- Warrior room: f/;/,. Repeat the last find with ; to step through identical separators.
return {
  id = "warrior_ft_chain",
  tier = "warrior",
  command = "f / t / ; / ,",
  title = "f/t Motion Chain",
  description = "; repeats the last f/t forward; , reverses it.",
  usage_tip = "ff finds next 'f'. ; jumps to the one after. , goes back.",
  efficiency_hint = "Prefix f with a count (2f,) to reach the second match.",
  before_example = "a, b, |c, d",
  after_example = "a, b, |X, d",
  filetype = "lua",
  cursor_start = { row = 1, col = 1 },
  time_limit = 55,
  goal = "Change the third item `c` to `X`.",
  start_text = [[
local items = { "a", "b", "c", "d", "e" }]],
  target_text = [[
local items = { "a", "b", "X", "d", "e" }]],
  base_xp = 85,
  optimal_keystrokes = { "2", "f", "c", "r", "X" },
  optimal_keystrokes_alternates = {
    { "f", "c", ";", "r", "X" },
    { "5", "f", "\"", "l", "r", "X" },
  },
}
