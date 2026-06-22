-- Beginner room: a/A/o/O. Add header above, append commas, add trailing item.
return {
  id = "beginner_insert2",
  tier = "beginner",
  command = "a / A / o / O",
  title = "Insert Variants",
  description = "A = append at end of line. o = open line below. O = open line above.",
  before_example = "one|\ntwo",
  after_example = "items:|\none,\ntwo,\nthree",
  usage_tip = "A puts you at end of line in insert mode. o opens a new line below.",
  efficiency_hint = "A appends at line end, o opens a line below; pick the right entry.",
  filetype = "text",
  cursor_start = { row = 1, col = 1 },
  time_limit = 75,
  goal = "Add header `items:` above, comma to lines 1+2, then `three` below.",
  start_text = [[
one
two]],
  target_text = [[
items:
one,
two,
three]],
  base_xp = 55,
  optimal_keystrokes = { "O", "i", "t", "e", "m", "s", ":", "\27", "j", "A", ",", "\27", "j", "A", ",", "\27", "o", "t", "h", "r", "e", "e", "\27" },
}
