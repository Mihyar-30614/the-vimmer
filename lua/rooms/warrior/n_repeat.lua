-- Warrior room: /pattern + cgn + .. Search-driven repeated edits.
return {
  id = "warrior_n_repeat",
  tier = "warrior",
  command = "/pattern + cgn + .",
  title = "Search and Repeat",
  description = "Search for a pattern, change next match (cgn), repeat with .",
  usage_tip = "/foo<CR> finds first match. cgn changes it. . repeats. n+. is the older form.",
  efficiency_hint = "After cgn, press . to apply the change at each match.",
  before_example = "|foo\nfoo\nfoo",
  after_example = "|bar\nbar\nbar",
  filetype = "lua",
  cursor_start = { row = 1, col = 1 },
  time_limit = 70,
  goal = "Rename all 4 instances of `temp` to `final`.",
  start_text = [[
local temp = 1
local x = temp + 2
local y = temp * 3
local z = temp - 4]],
  target_text = [[
local final = 1
local x = final + 2
local y = final * 3
local z = final - 4]],
  base_xp = 100,
  optimal_keystrokes = { "/", "t", "e", "m", "p", "\r", "c", "g", "n", "f", "i", "n", "a", "l", "\27", ".", ".", "." },
  optimal_keystrokes_alternates = {
    { "/", "t", "e", "m", "p", "\r", "c", "i", "w", "f", "i", "n", "a", "l", "\27", "n", ".", "n", ".", "n", "." },
  },
}
