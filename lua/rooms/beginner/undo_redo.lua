-- Beginner room: u / Ctrl-r. Make an edit, undo it, redo it.
return {
  id = "beginner_undo_redo",
  tier = "beginner",
  command = "u / Ctrl-r",
  title = "Undo & Redo: u, Ctrl-r",
  description = "Undo last change (u), redo an undone change (Ctrl-r)",
  before_example = "x = old|",
  after_example = "x = new|",
  usage_tip = "u is your safety net. Ctrl-r redoes what you undid.",
  efficiency_hint = "u undoes and Ctrl-r redoes; one keystroke each.",
  filetype = "lua",
  cursor_start = { row = 1, col = 11 },
  goal = "Change `old` to `new`. (Then practice: press u to revert, Ctrl-r to redo.)",
  start_text = [[
local x = old]],
  target_text = [[
local x = new]],
  base_xp = 50,
  optimal_keystrokes = { "c", "w", "n", "e", "w", "\27", "u", "\18" },
}
