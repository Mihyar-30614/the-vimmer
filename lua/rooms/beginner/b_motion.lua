-- Beginner room: `b` backward-word motion. Walk back from end-of-line to fix a word.
return {
  id = "beginner_b_motion",
  tier = "beginner",
  command = "b",
  title = "Word Motion: b",
  description = "Move to the start of the previous word",
  before_example = "fix this line |now",
  after_example = "fix |This line now",
  usage_tip = "Jump backward word by word. Pair with w for fast navigation.",
  efficiency_hint = "Press b to hop back whole words; don't h one char at a time.",
  filetype = "text",
  cursor_start = { row = 1, col = 31 },
  goal = "From the end, back up to `broken` and capitalize the `b`.",
  start_text = [[
fix the broken word here please]],
  target_text = [[
fix the Broken word here please]],
  base_xp = 40,
  optimal_keystrokes = { "b", "b", "b", "b", "r", "B" },
  optimal_keystrokes_alternates = {
    { "4", "b", "r", "B" },
  },
}
