-- Beginner room: hjkl basic navigation. Navigation-only — no text transformation required.
return {
  id = "beginner_hjkl",
  tier = "beginner",
  command = "h / j / k / l",
  title = "Basic Motions: hjkl",
  description = "Move cursor left (h), down (j), up (k), right (l)",
  before_example = "|hello world",
  after_example = "hell|o world",
  usage_tip = "Stay on home row. Never reach for arrow keys again.",
  start_text = "move right to reach the end",
  target_text = "move right to reach the end",
  base_xp = 30,
  optimal_keystrokes = { "l", "l", "l", "l" },
}
