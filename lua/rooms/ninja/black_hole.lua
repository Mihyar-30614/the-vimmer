-- Ninja room: "_ black hole register. Yank a value, delete junk without overwriting it, then paste.
return {
  id = "ninja_black_hole",
  tier = "ninja",
  command = '"_d / "_dd',
  title = 'Black Hole Register: "_',
  description = 'Deleting with "_ discards text without overwriting the unnamed yank register',
  before_example = "PASTE_ME\n|JUNK\nhere",
  after_example = "here\nPASTE_ME",
  usage_tip = '"_ is the black hole — anything deleted into it is gone. Use "_dd to delete a line without losing what you yanked.',
  start_text = "PASTE_ME\nJUNK\nhere",
  target_text = "PASTE_ME\nhere\nPASTE_ME",
  base_xp = 115,
  optimal_keystrokes = { "y", "y", "j", '"', "_", "d", "d", "p" },
}
