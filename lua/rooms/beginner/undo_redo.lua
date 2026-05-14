-- Beginner room: u/Ctrl-r (undo/redo). start_text == target_text; player triggers undo to "fix" the file.
return {
  id = "beginner_undo_redo",
  tier = "beginner",
  command = "u / Ctrl-r",
  title = "Undo & Redo: u, Ctrl-r",
  description = "Undo last change (u), redo an undone change (Ctrl-r)",
  before_example = "correct text (after accidental edit)",
  after_example = "correct text",
  usage_tip = "u is your safety net. Experiment freely knowing you can always undo.",
  start_text = "correct text",
  target_text = "correct text",
  base_xp = 30,
  optimal_keystrokes = { "u" },
}
