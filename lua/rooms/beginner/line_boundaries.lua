-- Beginner room: 0 / $ / ^ (line boundaries). Navigation-only.
return {
  id = "beginner_line_boundaries",
  tier = "beginner",
  command = "0 / $ / ^",
  title = "Line Boundaries: 0, $, ^",
  description = "0 = column 0; $ = end of line; ^ = first non-blank char",
  before_example = "|    indented line ending here",
  after_example = "    indented line ending here|",
  usage_tip = "0 hits raw start. ^ skips leading whitespace. $ jumps to last char.",
  start_text = "    indented start    and trailing",
  target_text = "    indented start    and trailing",
  base_xp = 45,
  optimal_keystrokes = { "$" },
}
