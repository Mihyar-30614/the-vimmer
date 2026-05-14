-- Beginner room: i/a/o (insert mode entry). Player navigates to a gap and inserts a missing letter.
return {
  id = "beginner_insert_mode",
  tier = "beginner",
  command = "i / a / o",
  title = "Insert Mode: i, a, o",
  description = "Enter insert mode: before cursor (i), after cursor (a), new line below (o)",
  before_example = "helo world",
  after_example = "hello world",
  usage_tip = "i inserts BEFORE cursor. Move to the gap, press i, type, then <Esc>.",
  start_text = "helo world",
  target_text = "hello world",
  base_xp = 50,
  optimal_keystrokes = { "l", "l", "l", "i", "l", "\27" },
}
