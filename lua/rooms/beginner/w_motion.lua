-- Beginner room: w (forward word jump). Navigation-only — no text transformation required.
return {
  id = "beginner_w_motion",
  tier = "beginner",
  command = "w",
  title = "Word Motion: w",
  description = "Move to the start of the next word",
  before_example = "|fix this line now",
  after_example = "fix |this line now",
  usage_tip = "Jump word by word forward. Faster than holding l.",
  start_text = "fix this line now",
  target_text = "fix this line now",
  base_xp = 40,
  optimal_keystrokes = { "w" },
}
