-- Warrior room: H / M / L (viewport jumps). Navigation-only.
return {
  id = "warrior_viewport",
  tier = "warrior",
  command = "H / M / L",
  title = "Viewport Jumps: H, M, L",
  description = "H = top of screen, M = middle, L = bottom",
  before_example = "|top visible row",
  after_example = "top visible row\n…\n|bottom visible row",
  usage_tip = "Jumps within the visible window — not the whole file. Quick when scrolling around.",
  start_text = "row 1\nrow 2\nrow 3\nrow 4\nrow 5\nrow 6\nrow 7",
  target_text = "row 1\nrow 2\nrow 3\nrow 4\nrow 5\nrow 6\nrow 7",
  base_xp = 70,
  optimal_keystrokes = { "L" },
}
