-- Beginner room: 0/$/^. Trim trailing `;` from three lines.
return {
  id = "beginner_line_boundaries",
  tier = "beginner",
  command = "0 / $ / ^",
  title = "Line Boundaries: 0, $, ^",
  description = "0 = column 0; $ = end of line; ^ = first non-blank char",
  before_example = "key = value|;",
  after_example = "key = value|",
  usage_tip = "0 hits raw start. ^ skips leading whitespace. $ jumps to last char.",
  efficiency_hint = "$ jumps to line end and 0 to the start; no l/h crawling.",
  filetype = "lua",
  cursor_start = { row = 1, col = 1 },
  goal = "Delete the trailing `;` on each of the three lines.",
  start_text = [[
local a = 1;
local b = 2;
local c = 3;]],
  target_text = [[
local a = 1
local b = 2
local c = 3]],
  base_xp = 45,
  optimal_keystrokes = { "$", "x", "j", "$", "x", "j", "$", "x" },
  optimal_keystrokes_alternates = {
    { "A", "\27", "x", "j", "A", "\27", "x", "j", "A", "\27", "x" },
  },
}
