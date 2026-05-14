-- Beginner room: r<char> (replace single character). Player fixes a typo without entering insert mode.
return {
  id = "beginner_replace_char",
  tier = "beginner",
  command = "r<char>",
  title = "Replace Char: r",
  description = "Replace the character under the cursor without entering insert mode",
  before_example = "the wr|Xng answer",
  after_example = "the wrong answer",
  usage_tip = "r replaces exactly one char and stays in normal mode. Faster than i + char + Esc for single fixes.",
  start_text = "the wrXng answer",
  target_text = "the wrong answer",
  base_xp = 40,
  optimal_keystrokes = { "f", "X", "r", "o" },
}
