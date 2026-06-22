-- Beginner room: x. Delete stray characters from real code.
return {
  id = "beginner_delete_char",
  tier = "beginner",
  command = "x",
  title = "Delete Char: x",
  description = "x deletes the char under the cursor; X deletes the char before",
  before_example = "x|y = 1",
  after_example = "x| = 1",
  usage_tip = "x deletes under cursor. X deletes BEFORE cursor. Combine with $ to trim trailing junk.",
  efficiency_hint = "Jump with f<char> to land on the target before x.",
  filetype = "lua",
  cursor_start = { row = 1, col = 7 },
  goal = "Remove the stray `q` on line 1 and the stray `z` on line 2.",
  start_text = [[
local qcount = 0
local indezx = 1]],
  target_text = [[
local count = 0
local index = 1]],
  base_xp = 50,
  optimal_keystrokes = { "x", "j", "f", "z", "x" },
}
