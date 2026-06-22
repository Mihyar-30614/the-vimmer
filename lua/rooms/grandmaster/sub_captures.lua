-- Grandmaster: swap two words on each line with capture groups.
return {
  id = "grandmaster_sub_captures",
  tier = "grandmaster",
  command = ":s/\\(\\w\\+\\) \\(\\w\\+\\)/\\2 \\1/",
  title = "Substitute: Capture Groups",
  description = "Reorder text by capturing pieces with \\( \\) and replaying them as \\1 \\2.",
  before_example = "alpha beta",
  after_example = "beta alpha",
  usage_tip = "Capture with \\( \\), reference captures as \\1, \\2 in the replacement.",
  efficiency_hint = "One :%s with \\(\\) capture groups swaps both lines at once.",
  filetype = "text",
  cursor_start = { row = 1, col = 1 },
  goal = "Swap the two words on every line using capture groups.",
  start_text = [[
alpha beta
gamma delta]],
  target_text = [[
beta alpha
delta gamma]],
  base_xp = 90,
  time_limit = 75,
  optimal_keystrokes = {
    ":", "%", "s", "/", "\\", "(", "\\", "w", "\\", "+", "\\", ")", " ",
    "\\", "(", "\\", "w", "\\", "+", "\\", ")", "/", "\\", "2", " ", "\\", "1", "/", "\r",
  },
}
