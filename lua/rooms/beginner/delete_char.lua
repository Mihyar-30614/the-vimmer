-- Beginner room: x (delete char under cursor). Trim trailing X's from the end of the line.
return {
  id = "beginner_delete_char",
  tier = "beginner",
  command = "x",
  title = "Delete Char: x",
  description = "x deletes the char under the cursor; X deletes the char before",
  before_example = "vim is great|XXX",
  after_example = "vim is great|",
  usage_tip = "x deletes under cursor. X deletes BEFORE cursor. Combine with $ to trim trailing junk.",
  start_text = "vim is greatXXX",
  target_text = "vim is great",
  base_xp = 60,
  optimal_keystrokes = { "$", "x", "x", "x" },
}
