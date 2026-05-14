-- Beginner room: b (backward word jump). Navigation-only — no text transformation required.
return {
  id = "beginner_b_motion",
  tier = "beginner",
  command = "b",
  title = "Word Motion: b",
  description = "Move to the start of the previous word",
  before_example = "fix this line |now",
  after_example = "fix this |line now",
  usage_tip = "Jump backward word by word. Pair with w for fast navigation.",
  start_text = "revert this change now",
  target_text = "revert this change now",
  base_xp = 40,
  optimal_keystrokes = { "b" },
}
