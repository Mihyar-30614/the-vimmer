-- Warrior room: :N. Type :LINE<CR> to jump to a specific line, then edit.
return {
  id = "warrior_goto_line",
  tier = "warrior",
  command = ":N",
  title = "Goto Line: :N",
  description = "Type :NUMBER<CR> to jump to that line.",
  usage_tip = ":7<CR> is the same as 7G. Pairs naturally with line numbers in the gutter.",
  efficiency_hint = "Jump to a line with :N or NG instead of scrolling.",
  before_example = "line 1\n|line 5",
  after_example = "line 1\n|LINE 5",
  filetype = "text",
  cursor_start = { row = 1, col = 1 },
  time_limit = 50,
  goal = "Jump to line 5 and uppercase it.",
  start_text = [[
header
config one
config two
config three
target line]],
  target_text = [[
header
config one
config two
config three
TARGET LINE]],
  base_xp = 75,
  optimal_keystrokes = { ":", "5", "\r", "g", "U", "U" },
  optimal_keystrokes_alternates = {
    { "5", "G", "g", "U", "U" },
    { "G", "g", "U", "U" },
  },
}
