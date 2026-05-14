-- Beginner room: ~ (toggle case). Each press flips the char under the cursor and advances right.
return {
  id = "beginner_toggle_case",
  tier = "beginner",
  command = "~",
  title = "Toggle Case: ~",
  description = "Flip case of char under cursor and advance",
  before_example = "|Hello",
  after_example = "hELLO|",
  usage_tip = "Press ~ repeatedly. With count: 5~ flips next 5 chars in one go.",
  start_text = "Hello",
  target_text = "hELLO",
  base_xp = 55,
  optimal_keystrokes = { "~", "~", "~", "~", "~" },
}
