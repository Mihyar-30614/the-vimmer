-- Beginner room: `w` forward-word motion. Hop to the broken word and fix one char.
return {
  id = "beginner_w_motion",
  tier = "beginner",
  command = "w",
  title = "Word Motion: w",
  description = "Move to the start of the next word",
  before_example = "the quick |brown fox",
  after_example = "the quick |brawn fox",
  usage_tip = "Jump word by word forward. Faster than holding l.",
  filetype = "text",
  cursor_start = { row = 1, col = 1 },
  goal = "Hop to `brown` and change the `o` to `a`.",
  start_text = [[
the quick brown fox jumps over the lazy dog]],
  target_text = [[
the quick brawn fox jumps over the lazy dog]],
  base_xp = 40,
  optimal_keystrokes = { "w", "w", "l", "l", "r", "a" },
  optimal_keystrokes_alternates = {
    { "2", "w", "l", "l", "r", "a" },
  },
}
