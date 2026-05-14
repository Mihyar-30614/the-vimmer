-- Beginner room: J (join lines). Player merges two lines into one with a single keystroke.
return {
  id = "beginner_join_lines",
  tier = "beginner",
  command = "J",
  title = "Join Lines: J",
  description = "J joins the current line with the line below it, inserting a space between them",
  before_example = "hello|\nworld",
  after_example = "hello world",
  usage_tip = "J is faster than going to end of line and deleting the newline. 2J joins 3 lines at once.",
  start_text = "hello\nworld",
  target_text = "hello world",
  base_xp = 30,
  optimal_keystrokes = { "J" },
}
