-- Warrior room: cw + . (change-word and dot repeat). Player changes one occurrence then repeats with dot.
return {
  id = "warrior_change_chain",
  tier = "warrior",
  command = "cw / .",
  title = "Change and Repeat",
  description = "cw changes a word. . repeats the last change at the cursor position.",
  before_example = "|old_name(x)",
  after_example = "|new_name(x)",
  usage_tip = "cw replaces from cursor to end of word. . repeats on the next occurrence.",
  start_text = "old_name(x)\nold_name(y)\nold_name(z)",
  target_text = "new_name(x)\nnew_name(y)\nnew_name(z)",
  base_xp = 75,
  time_limit = 55,
  optimal_keystrokes = { "c", "w", "n", "e", "w", "_", "n", "a", "m", "e", "\27", "j", ".", "j", "." },
}
