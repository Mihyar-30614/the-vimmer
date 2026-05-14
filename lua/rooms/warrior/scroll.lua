-- Warrior room: zz / zt / zb (center / top / bottom scroll). Navigation-only.
return {
  id = "warrior_scroll",
  tier = "warrior",
  command = "zz / zt / zb",
  title = "Center View: zz, zt, zb",
  description = "zz centers cursor line; zt puts it at top; zb at bottom",
  before_example = "|line on cursor",
  after_example = "(window scrolls to center it)",
  usage_tip = "Great after a big jump (G, /search, gg). zz feels like re-anchoring.",
  start_text = "anchor 1\nanchor 2\nanchor 3\nanchor 4\nanchor 5",
  target_text = "anchor 1\nanchor 2\nanchor 3\nanchor 4\nanchor 5",
  base_xp = 70,
  optimal_keystrokes = { "z", "z" },
}
