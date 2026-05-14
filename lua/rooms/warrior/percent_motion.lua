-- Warrior room: % (jump to matching bracket). Navigation-only — player jumps to the closing bracket.
return {
  id = "warrior_percent",
  tier = "warrior",
  command = "%",
  title = "Jump to Match: %",
  description = "Jump between matching bracket pairs: (), [], {}",
  before_example = "|(outer (inner) outer)",
  after_example = "(outer (inner) outer|)",
  usage_tip = "% jumps to the matching bracket. Essential for navigating nested code.",
  start_text = "function foo(bar, baz) { return bar + baz; }",
  target_text = "function foo(bar, baz) { return bar + baz; }",
  base_xp = 70,
  optimal_keystrokes = { "f", "(", "%" },
}
