-- Beginner room: x/dd/yy/p basics. Player deletes a single bad line with dd.
return {
  id = "beginner_delete_yank",
  tier = "beginner",
  command = "x / dd / yy / p",
  title = "Delete & Paste: x, dd, yy, p",
  description = "Delete char (x), delete line (dd), yank line (yy), paste (p)",
  before_example = "good line\nbad line\ngood line",
  after_example = "good line\ngood line",
  usage_tip = "dd deletes the whole line into a register. Nothing is truly deleted in Vim.",
  start_text = "good line\nbad line\ngood line",
  target_text = "good line\ngood line",
  base_xp = 60,
  optimal_keystrokes = { "j", "d", "d" },
}
