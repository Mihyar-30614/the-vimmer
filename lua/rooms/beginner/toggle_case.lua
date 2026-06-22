-- Beginner room: ~. Flip case of a wrongly-cased identifier.
return {
  id = "beginner_toggle_case",
  tier = "beginner",
  command = "~",
  title = "Toggle Case: ~",
  description = "Flip case of char under cursor and advance",
  before_example = "|HELLO",
  after_example = "hello|",
  usage_tip = "Press ~ repeatedly. With count: 5~ flips next 5 chars in one go.",
  efficiency_hint = "Prefix a count (5~) to flip several characters at once.",
  filetype = "lua",
  cursor_start = { row = 1, col = 7 },
  goal = "Lowercase the constant `HELLO` to `hello`.",
  start_text = [[
local HELLO = "world"]],
  target_text = [[
local hello = "world"]],
  base_xp = 50,
  optimal_keystrokes = { "5", "~" },
  optimal_keystrokes_alternates = {
    { "~", "~", "~", "~", "~" },
  },
}
