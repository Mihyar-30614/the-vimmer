-- Warrior room: :N (goto line). Navigation-only — player types :5<CR>.
return {
  id = "warrior_goto_line",
  tier = "warrior",
  command = ":N",
  title = "Goto Line: :N",
  description = "Type :NUMBER<CR> to jump to that line",
  before_example = "|line 1\n...\nline 7",
  after_example = "line 1\n...\n|line 7",
  usage_tip = ":7<CR> is the same as 7G. Pairs naturally with line numbers in the gutter.",
  start_text = "line 1\nline 2\nline 3\nline 4\nline 5\nline 6\nline 7",
  target_text = "line 1\nline 2\nline 3\nline 4\nline 5\nline 6\nline 7",
  base_xp = 75,
  optimal_keystrokes = { ":", "5", "\r" },
}
