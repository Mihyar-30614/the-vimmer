-- Beginner room: D / d$. Strip trailing inline comments from two lines.
return {
  id = "beginner_d_dollar",
  tier = "beginner",
  command = "D / d$",
  title = "Delete to Line End: D",
  description = "D deletes from the cursor to the end of the line (shorthand for d$). $ jumps to line end.",
  before_example = "x = 1 |-- TODO",
  after_example = "x = 1|",
  usage_tip = "D = d$. Combine $ with any operator: d$ deletes, c$ changes, y$ yanks to end of line.",
  filetype = "lua",
  cursor_start = { row = 1, col = 12 },
  goal = "Delete the `-- TODO` trailing comment on lines 1 and 2.",
  start_text = [[
local a = 1 -- TODO
local b = 2 -- TODO
local c = 3]],
  target_text = [[
local a = 1
local b = 2
local c = 3]],
  base_xp = 50,
  optimal_keystrokes = { "D", "j", "l", "D" },
  optimal_keystrokes_alternates = {
    { "d", "$", "j", "l", "d", "$" },
  },
}
