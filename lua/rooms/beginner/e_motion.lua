-- Beginner room: `e` end-of-word. Land on the last char of a word and append a suffix.
return {
  id = "beginner_e_motion",
  tier = "beginner",
  command = "e",
  title = "Word Motion: e",
  description = "Move to the end of the current or next word",
  before_example = "|foo bar baz",
  after_example = "foo bar baz|!",
  usage_tip = "Use e to land at the end of a word, e.g. before appending a char.",
  filetype = "text",
  cursor_start = { row = 1, col = 1 },
  goal = "Land on the end of `baz` and append `!`.",
  start_text = [[
foo bar baz]],
  target_text = [[
foo bar baz!]],
  base_xp = 40,
  optimal_keystrokes = { "e", "e", "e", "a", "!", "\27" },
  optimal_keystrokes_alternates = {
    { "3", "e", "a", "!", "\27" },
  },
}
