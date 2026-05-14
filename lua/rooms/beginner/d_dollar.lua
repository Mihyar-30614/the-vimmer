-- Beginner room: D / d$ (delete to end of line). Player jumps to the colon and deletes the rest.
return {
  id = "beginner_d_dollar",
  tier = "beginner",
  command = "D / d$",
  title = "Delete to Line End: D",
  description = "D deletes from the cursor to the end of the line (shorthand for d$). $ jumps to line end.",
  before_example = "|keep: remove this",
  after_example = "keep:|",
  usage_tip = "D = d$. Combine $ with any operator: d$ deletes, c$ changes, y$ yanks to end of line. 0 = col 0, ^ = first non-blank.",
  start_text = "keep: remove this",
  target_text = "keep:",
  base_xp = 45,
  optimal_keystrokes = { "f", ":", "l", "D" },
}
