-- Beginner room: J. Join a function call that wraps across multiple lines.
return {
  id = "beginner_join_lines",
  tier = "beginner",
  command = "J",
  title = "Join Lines: J",
  description = "J joins the current line with the line below it, inserting a space between them",
  before_example = "log(\n  msg)",
  after_example = "log( msg)|",
  usage_tip = "J is faster than going to end of line and deleting the newline. 3J joins 3 lines at once.",
  filetype = "lua",
  cursor_start = { row = 1, col = 1 },
  goal = "Join the wrapped `print` call onto one line.",
  start_text = [[
print(
  "hello",
  "world"
)]],
  target_text = [[
print( "hello", "world")]],
  base_xp = 35,
  optimal_keystrokes = { "4", "J" },
  optimal_keystrokes_alternates = {
    { "J", "J", "J" },
  },
}
